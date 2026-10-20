#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>

static NSString * const kPrefs = @"/var/mobile/Library/Preferences/com.tu.islandpro.plist";
static NSString * const kAsset = @"/var/mobile/Library/Preferences/com.tu.islandpro.asset.png";
static char kOverlayKey;
static BOOL gEnabled = NO;
static CGFloat gAlpha = 1.0;
static CGFloat gScale = 1.0;
static CGFloat gOffsetX = 0.0;
static CGFloat gOffsetY = 0.0;
static BOOL gGlowEnabled = NO;
static CGFloat gGlowRadius = 8.0;
static BOOL gGlowPulse = NO;
static NSString *gImagePath = nil;
static NSHashTable<UIView *> *gHosts;
static UIImage *gCachedImage;
static NSString *gCachedPath;
static BOOL gNeedsRefresh = YES;
static BOOL gInsideLayoutHook = NO;
static NSString * const kStatusPath = @"/var/mobile/Library/Preferences/com.tu.islandpro.status.plist";
static NSString *gLastStatus = nil;
static void IPStatus(NSString *status) {
    if (!status.length || [gLastStatus isEqualToString:status]) return;
    gLastStatus = [status copy];
    NSDictionary *record = @{@"status": status, @"time": @([[NSDate date] timeIntervalSince1970]),
                             @"version": @"1.1.2"};
    [record writeToFile:kStatusPath atomically:YES];
    NSLog(@"[IslandPro] status: %@", status);
}


static CGFloat IPClampedNumber(id value, CGFloat fallback, CGFloat minimum, CGFloat maximum) {
    if (![value respondsToSelector:@selector(doubleValue)]) return fallback;
    double number = [value doubleValue];
    if (!isfinite(number)) return fallback;
    return (CGFloat)fmax((double)minimum, fmin((double)maximum, number));
}
static void IPReload(void) {
    NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:kPrefs] ?: @{};
    gEnabled = [p[@"enabled"] boolValue];
    gAlpha = IPClampedNumber(p[@"opacity"], 1.0, 0.0, 1.0);
    gScale = IPClampedNumber(p[@"scale"], 1.0, 0.5, 1.5);
    gOffsetX = IPClampedNumber(p[@"offsetX"], 0.0, -80.0, 80.0);
    gOffsetY = IPClampedNumber(p[@"offsetY"], 0.0, -40.0, 40.0);
    gGlowEnabled = [p[@"glowEnabled"] boolValue];
    gGlowRadius = IPClampedNumber(p[@"glowRadius"], 8.0, 0.0, 25.0);
    gGlowPulse = [p[@"glowPulse"] boolValue];
    NSString *s = p[@"imagePath"];
    gImagePath = [s isKindOfClass:[NSString class]] ? [s copy] : nil;
    gNeedsRefresh = YES;
    gCachedImage = nil;
    gCachedPath = nil;
}
static UIImage *IPImage(void) {
    if (gImagePath.length == 0) { gCachedImage = nil; gCachedPath = nil; return nil; }
    // Never decode image data on every layoutSubviews callback.
    if (!gNeedsRefresh && [gCachedPath isEqualToString:gImagePath]) return gCachedImage;
    gNeedsRefresh = NO;
    gCachedPath = [gImagePath copy];
    // Only load user-selected files inside the mobile preferences directory.
    if (![gImagePath isEqualToString:kAsset]) { gCachedImage = nil; return nil; }
    gCachedImage = [UIImage imageWithContentsOfFile:gImagePath];
    if (gCachedImage && (gCachedImage.size.width <= 0 || gCachedImage.size.height <= 0 || gCachedImage.size.width * gCachedImage.size.height > 16000000.0)) {
        gCachedImage = nil;
    }
    return gCachedImage;
}
static void IPUpdate(UIView *host) {
    if (!host) return;
    UIImageView *overlay = objc_getAssociatedObject(host, &kOverlayKey);
    if (!host.window || host.bounds.size.width <= 0 || host.bounds.size.height <= 0 || host.hidden || host.alpha <= 0.01) {
        if (overlay) { overlay.hidden = YES; [overlay.layer removeAnimationForKey:@"ip.glow.pulse"]; }
        return;
    }
    if (!gEnabled || gImagePath.length == 0) { if (overlay) { overlay.hidden = YES; [overlay.layer removeAnimationForKey:@"ip.glow.pulse"]; } return; }
    UIImage *image = IPImage();
    if (!image) { IPStatus(@"素材未加载：请检查路径与文件"); if (overlay) { overlay.hidden = YES; [overlay.layer removeAnimationForKey:@"ip.glow.pulse"]; } return; }
    if (!overlay) {
        overlay = [[UIImageView alloc] initWithFrame:CGRectZero];
        overlay.userInteractionEnabled = NO;
        overlay.contentMode = UIViewContentModeScaleAspectFit;
        overlay.clipsToBounds = YES;
        objc_setAssociatedObject(host, &kOverlayKey, overlay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [host addSubview:overlay];
    }
    if (overlay.image != image) overlay.image = image;
    overlay.alpha = gAlpha;
    CGFloat width = host.bounds.size.width * gScale;
    CGFloat height = host.bounds.size.height * gScale;
    // Keep the material within a bounded size even when a third-party island expands the host.
    width = MIN(width, 420.0);
    height = MIN(height, 180.0);
    overlay.frame = CGRectMake((host.bounds.size.width - width)/2 + gOffsetX,
                               (host.bounds.size.height - height)/2 + gOffsetY,
                               width, height);
    overlay.hidden = NO;
    IPStatus(@"素材已挂载到 SystemAperture 宿主");
    overlay.layer.shadowColor = [UIColor cyanColor].CGColor;
    overlay.layer.shadowOpacity = gGlowEnabled ? 0.85f : 0.0f;
    overlay.layer.shadowRadius = gGlowRadius;
    overlay.layer.shadowOffset = CGSizeZero;
    BOOL animateGlow = gEnabled && gGlowEnabled && gGlowPulse && !UIAccessibilityIsReduceMotionEnabled();
    if (animateGlow) {
        if (![overlay.layer animationForKey:@"ip.glow.pulse"]) {
            CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
            pulse.fromValue = @(0.25);
            pulse.toValue = @(0.85);
            pulse.duration = 1.25;
            pulse.autoreverses = YES;
            pulse.repeatCount = HUGE_VALF;
            pulse.removedOnCompletion = NO;
            [overlay.layer addAnimation:pulse forKey:@"ip.glow.pulse"];
        }
    } else {
        [overlay.layer removeAnimationForKey:@"ip.glow.pulse"];
    }
    overlay.layer.masksToBounds = NO;
    overlay.clipsToBounds = NO;
    if (overlay.superview != host) {
        [host addSubview:overlay];
    } else if (host.subviews.lastObject != overlay) {
        // SystemAperture may reorder its own subviews on a later layout pass.
        // Keep the noninteractive material visible without recreating the view.
        [host bringSubviewToFront:overlay];
    }
}
static void (*originalLayout)(id,SEL);
static void hookedLayout(id self, SEL cmd) {
    // Preserve the original layout behavior, but avoid running our overlay
    // update recursively when UIKit performs a nested layout.
    BOOL nested = gInsideLayoutHook;
    if (!nested) gInsideLayoutHook = YES;
    @try {
        if (originalLayout) originalLayout(self,cmd);
        if (nested) return;
        UIView *host = (UIView *)self;
        if (!gHosts) gHosts = [NSHashTable weakObjectsHashTable];
        [gHosts addObject:host];
        IPUpdate(host);
    } @finally {
        if (!nested) gInsideLayoutHook = NO;
    }
}
// A host can attach/detach without a fresh layout pass. Synchronize the
// overlay at that lifecycle boundary so stale images do not linger.
static void (*originalDidMoveToWindow)(id, SEL);
static void hookedDidMoveToWindow(id self, SEL cmd) {
    if (originalDidMoveToWindow) originalDidMoveToWindow(self, cmd);
    UIView *host = (UIView *)self;
    if (!gHosts) gHosts = [NSHashTable weakObjectsHashTable];
    [gHosts addObject:host];
    IPUpdate(host);
}
static void IPNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        IPReload();
        // Update detached hosts too: IPUpdate hides their existing overlays and
        // stops animations; skipping them leaves stale presentation state behind.
        for (UIView *host in gHosts.allObjects) {
            IPUpdate(host);
        }
    });
}
static BOOL gHookInstalled = NO;
static void IPInstallHookIfAvailable(void) {
    if (gHookInstalled) return;
    Class c = objc_getClass("SBSystemApertureContainerView");
    if (!c || ![c instancesRespondToSelector:@selector(layoutSubviews)]) return;
    MSHookMessageEx(c, @selector(layoutSubviews), (IMP)hookedLayout, (IMP *)&originalLayout);
    if ([c instancesRespondToSelector:@selector(didMoveToWindow)]) {
        MSHookMessageEx(c, @selector(didMoveToWindow), (IMP)hookedDidMoveToWindow,
                        (IMP *)&originalDidMoveToWindow);
    }
    gHookInstalled = YES;
    IPStatus(@"已找到并 Hook SystemAperture 容器");
    NSLog(@"[IslandPro] Hook registered: SBSystemApertureContainerView layoutSubviews");
}
// A function-based retry avoids a block retaining itself across delayed callbacks.
static void IPInstallHookRetry(NSUInteger attempt) {
    if (gHookInstalled) return;
    if (attempt >= 20) {
        // Identify which SystemAperture classes are actually present on-device.
        // Do not hook guessed alternatives: log them for a safe, evidence-based fix.
        const char *candidates[] = {
            "SBSystemApertureContainerView",
            "SBSystemApertureViewController",
            "SBSystemApertureController",
            "SAUIElementView",
            "SBRecordingIndicatorViewController"
        };
        for (NSUInteger i = 0; i < sizeof(candidates)/sizeof(candidates[0]); i++) {
            Class candidate = objc_getClass(candidates[i]);
            NSLog(@"[IslandPro] Class probe %s: %@", candidates[i],
                  candidate ? @"present" : @"missing");
        }
        IPStatus(@"SpringBoard 已注入，但目标 SystemAperture 类未找到");
        NSLog(@"[IslandPro] Hook unavailable after 20 startup retries");
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        IPInstallHookIfAvailable();
        if (!gHookInstalled) IPInstallHookRetry(attempt + 1);
    });
}
__attribute__((constructor)) static void IPInit(void) {
    @autoreleasepool {
        IPReload();
        IPStatus(@"已注入 SpringBoard，等待宿主初始化");
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, IPNotification,
            CFSTR("com.tu.islandpro/preferences.changed"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        dispatch_async(dispatch_get_main_queue(), ^{
            IPInstallHookIfAvailable();
            if (!gHookInstalled) {
                NSLog(@"[IslandPro] Target class not yet available; scheduling bounded retry");
                IPInstallHookRetry(0);
            }
        });
    }
}
