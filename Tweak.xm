#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <CoreFoundation/CoreFoundation.h>

static NSString * const kPrefs = @"/var/jb/var/mobile/Library/Preferences/com.tu.islandpro.plist";
static char kOverlayKey;
static BOOL gEnabled = NO;
static CGFloat gAlpha = 1.0;
static CGFloat gScale = 1.0;
static NSString *gImagePath = nil;

static void IPReload(void) {
    NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:kPrefs] ?: @{};
    gEnabled = [p[@"enabled"] boolValue];
    gAlpha = p[@"opacity"] ? MAX(0.0, MIN(1.0, [p[@"opacity"] doubleValue])) : 1.0;
    gScale = p[@"scale"] ? MAX(0.5, MIN(1.5, [p[@"scale"] doubleValue])) : 1.0;
    NSString *s = p[@"imagePath"];
    gImagePath = [s isKindOfClass:[NSString class]] ? [s copy] : nil;
}
static void IPUpdate(UIView *host) {
    if (!host) return;
    UIImageView *overlay = objc_getAssociatedObject(host, &kOverlayKey);
    if (!gEnabled || gImagePath.length == 0) { overlay.hidden = YES; return; }
    UIImage *image = [UIImage imageWithContentsOfFile:gImagePath];
    if (!image) { overlay.hidden = YES; return; }
    if (!overlay) {
        overlay = [[UIImageView alloc] initWithFrame:CGRectZero];
        overlay.userInteractionEnabled = NO;
        overlay.contentMode = UIViewContentModeScaleAspectFit;
        overlay.clipsToBounds = YES;
        objc_setAssociatedObject(host, &kOverlayKey, overlay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [host addSubview:overlay];
    }
    overlay.image = image;
    overlay.alpha = gAlpha;
    overlay.frame = CGRectMake((host.bounds.size.width * (1-gScale))/2,
                               (host.bounds.size.height * (1-gScale))/2,
                               host.bounds.size.width*gScale,host.bounds.size.height*gScale);
    overlay.hidden = NO;
}
static void (*originalLayout)(id,SEL);
static void hookedLayout(id self, SEL cmd) {
    originalLayout(self,cmd);
    IPUpdate((UIView *)self);
}
static void IPNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        IPReload();
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:window];
            while (pending.count) {
                UIView *v = pending.lastObject; [pending removeLastObject];
                if ([NSStringFromClass(v.class) isEqualToString:@"SBSystemApertureContainerView"]) IPUpdate(v);
                [pending addObjectsFromArray:v.subviews];
            }
        }
    });
}
__attribute__((constructor)) static void IPInit(void) {
    @autoreleasepool {
        IPReload();
        Class c = objc_getClass("SBSystemApertureContainerView");
        if (c) {
            MSHookMessageEx(c, @selector(layoutSubviews), (IMP)hookedLayout, (IMP *)&originalLayout);
        }
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, IPNotification,
            CFSTR("com.tu.islandpro/preferences.changed"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}
