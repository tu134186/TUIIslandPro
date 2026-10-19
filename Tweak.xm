#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <CoreFoundation/CoreFoundation.h>

static NSString * const kPrefs = @"/var/mobile/Library/Preferences/com.tu.islandpro.plist";
static char kOverlayKey;
static BOOL gEnabled = NO;
static CGFloat gAlpha = 1.0;
static CGFloat gScale = 1.0;
static NSString *gImagePath = nil;
static NSHashTable<UIView *> *gHosts;
static UIImage *gCachedImage;
static NSString *gCachedPath;
static NSDate *gCachedModification;
static BOOL gNeedsRefresh = YES;

static void IPReload(void) {
    NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:kPrefs] ?: @{};
    gEnabled = [p[@"enabled"] boolValue];
    gAlpha = p[@"opacity"] ? MAX(0.0, MIN(1.0, [p[@"opacity"] doubleValue])) : 1.0;
    gScale = p[@"scale"] ? MAX(0.5, MIN(1.5, [p[@"scale"] doubleValue])) : 1.0;
    NSString *s = p[@"imagePath"];
    gImagePath = [s isKindOfClass:[NSString class]] ? [s copy] : nil;
    gNeedsRefresh = YES;
}
static UIImage *IPImage(void) {
    if (gImagePath.length == 0) return nil;
    // Never decode image data on every layoutSubviews callback.
    if (!gNeedsRefresh && [gCachedPath isEqualToString:gImagePath]) return gCachedImage;
    gNeedsRefresh = NO;
    gCachedPath = [gImagePath copy];
    gCachedImage = [UIImage imageWithContentsOfFile:gImagePath];
    return gCachedImage;
}
static void IPUpdate(UIView *host) {
    if (!host) return;
    UIImageView *overlay = objc_getAssociatedObject(host, &kOverlayKey);
    if (!gEnabled || gImagePath.length == 0) { if (overlay) overlay.hidden = YES; return; }
    UIImage *image = IPImage();
    if (!image) { if (overlay) overlay.hidden = YES; return; }
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
    overlay.frame = CGRectMake((host.bounds.size.width * (1-gScale))/2,
                               (host.bounds.size.height * (1-gScale))/2,
                               host.bounds.size.width*gScale, host.bounds.size.height*gScale);
    overlay.hidden = NO;
    if (overlay.superview != host) [host addSubview:overlay];
}
static void (*originalLayout)(id,SEL);
static void hookedLayout(id self, SEL cmd) {
    if (originalLayout) originalLayout(self,cmd);
    UIView *host = (UIView *)self;
    if (!gHosts) gHosts = [NSHashTable weakObjectsHashTable];
    [gHosts addObject:host];
    IPUpdate(host);
}
static void IPNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        IPReload();
        for (UIView *host in gHosts.allObjects) IPUpdate(host);
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
