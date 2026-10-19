#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>

static NSString * const IPPrefsPath = @"/var/mobile/Library/Preferences/com.tu.islandpro.plist";
static NSString * const IPAssetPath = @"/var/mobile/Library/Preferences/com.tu.islandpro.asset";
@interface IPRootListController : PSListController <UIDocumentPickerDelegate>
@end
@implementation IPRootListController
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:IPPrefsPath];
    return p[[specifier propertyForKey:@"key"]] ?: [specifier propertyForKey:@"default"];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSMutableDictionary *p = [[NSDictionary dictionaryWithContentsOfFile:IPPrefsPath] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key || !value) return;
    if ([p[key] isEqual:value]) return;
    p[key] = value;
    if ([p writeToFile:IPPrefsPath atomically:YES]) [self notifySpringBoard];
    else {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"保存失败" message:@"无法写入插件设置，请检查存储空间与权限。" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }
}
- (void)notifySpringBoard {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.tu.islandpro/preferences.changed"), NULL, NULL, YES);
}
- (void)chooseImage {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeImage] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    BOOL access = [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
    if (access) [url stopAccessingSecurityScopedResource];
    // Decode and re-encode as PNG to avoid trusting arbitrary file extensions.
    UIImage *image = (data && data.length <= 20*1024*1024) ? [UIImage imageWithData:data] : nil;
    // A tiny compressed photo can still expand into a huge bitmap.
    CGSize size = image.size;
    if (image && (size.width <= 0 || size.height <= 0 || size.width * size.height > 16000000.0)) image = nil;
    // Normalize EXIF orientation and downsample to a reasonable island texture.
    if (image) {
        CGFloat ratio = MIN(1.0, 1024.0 / MAX(image.size.width, image.size.height));
        CGSize target = CGSizeMake(MAX(1, round(image.size.width * ratio)), MAX(1, round(image.size.height * ratio)));
        UIGraphicsBeginImageContextWithOptions(target, NO, 1.0);
        [image drawInRect:CGRectMake(0, 0, target.width, target.height)];
        UIImage *normalized = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        image = normalized;
    }
    NSData *png = image ? UIImagePNGRepresentation(image) : nil;
    if (!png || png.length > 20*1024*1024) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"素材无法导入" message:@"请选择有效的静态图片，转换后不超过20MB。" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    NSString *path = [IPAssetPath stringByAppendingString:@".png"];
    if (![png writeToFile:path atomically:YES]) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"保存失败" message:@"无法写入本机素材目录。" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    NSMutableDictionary *p = [[NSDictionary dictionaryWithContentsOfFile:IPPrefsPath] mutableCopy] ?: [NSMutableDictionary dictionary];
    p[@"imagePath"] = path;
    if (![p writeToFile:IPPrefsPath atomically:YES]) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"设置保存失败" message:@"素材已导入，但图片设置未保存。请检查存储权限。" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    [self notifySpringBoard];
    [self reloadSpecifiers];
}
@end
