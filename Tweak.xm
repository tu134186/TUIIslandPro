#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <CoreFoundation/CoreFoundation.h>

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

static void IPReload(void) {
    NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:kPrefs] ?: @{};
    gEnabled = [p[@"enabled"] boolValue];
    gAlpha = p[@"opacity"] ? MAX(0.0, MIN(1.0, [p[@"opacity"] doubleValue])) : 1.0;
    gScale = p[@"scale"] ? MAX(0.5, MIN(1.5, [p[@"scale"] doubleValue])) : 1.0;
    gOffsetX = p[@"offsetX"] ? MAX(-80.0, MIN(80.0, [p[@"offsetX"] doubleValue])) : 0.0;
    gOffsetY = p[@"offsetY"] ? MAX(-40.0, MIN(40.0, [p[@"offsetY"] doubleValue])) : 0.0;
    gGlowEnabled = [p[@"glowEnabled"] boolValue];
    gGlowRadius = p[@"glowRadius"] ? MAX(0.0, MIN(25.0, [p[@"glowRadius"] doubleValue])) : 8.0;
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
    return gCachedImage;
}
static void IPUpdate(UIView *host) {
    if (!host) return;
    UIImageView *overlay = objc_getAssociatedObject(host, &kOverlayKey);
    if (host.bounds.size.width <= 0 || host.bounds.size.height <= 0 || host.hidden || host.alpha <= 0.01) {
        if (overlay) { overlay.hidden = YES; [overlay.layer removeAnimationForKey:@"ip.glow.pulse"]; }
        return;
    }
    if (!gEnabled || gImagePath.length == 0) { if (overlay) { overlay.hidden = YES; [overlay.layer removeAnimationForKey:@"ip.glow.pulse"]; } return; }
    UIImage *image = IPImage();
    if (!image) { if (overlay) { overlay.hidden = YES; [overlay.layer removeAnimationForKey:@"ip.glow.pulse"]; } return; }
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
    overlay.frame = CGRectMake((host.bounds.size.width * (1-gScale))/2 + gOffsetX,
                               (host.bounds.size.height * (1-gScale))/2 + gOffsetY,
                               host.bounds.size.width*gScale, host.bounds.size.height*gScale);
    overlay.hidden = NO;
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
    if (overlay.superview != host) [host addSubview:overlay];
}
static void (*originalLayout)(id,SEL);
static void hookedLayout(id self, SEL cmd) {
    if (originalLayout) originalLayout(self,cmd);
    if (gInsideLayoutHook) return;
    gInsideLayoutHook = YES;
    @try {
        UIView *host = (UIView *)self;
        if (!gHosts) gHosts = [NSHashTable weakObjectsHashTable];
        [gHosts addObject:host];
        IPUpdate(host);
    } @finally {
        gInsideLayoutHook = NO;
    }
}
static void IPNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        IPReload();
        for (UIView *host in gHosts.allObjects) {
            if (!host.window) continue;
            IPUpdate(host);
        }
    });
}
__attribute__((constructor)) static void IPInit(void) {
    @autoreleasepool {
        IPReload();
        Class c = objc_getClass("SBSystemApertureContainerView");
        if (c && [c instancesRespondToSelector:@selector(layoutSubviews)]) {
            MSHookMessageEx(c, @selector(layoutSubviews), (IMP)hookedLayout, (IMP *)&originalLayout);
        }
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, IPNotification,
            CFSTR("com.tu.islandpro/preferences.changed"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}
