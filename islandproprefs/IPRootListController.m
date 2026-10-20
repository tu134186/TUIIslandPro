#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>
#import <ImageIO/ImageIO.h>

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
    NSNumber *fileSize = nil;
    NSError *sizeError = nil;
    [url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:&sizeError];
    // Files providers do not always expose NSURLFileSizeKey for copied documents.
    // Fall back to local file attributes before deciding whether it is safe to read.
    if (!fileSize || sizeError) {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:nil];
        fileSize = attributes[NSFileSize];
    }
    NSData *data = nil;
    if (fileSize && fileSize.unsignedLongLongValue > 0 &&
        fileSize.unsignedLongLongValue <= 20ULL * 1024ULL * 1024ULL) {
        data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
    }
    if (access) [url stopAccessingSecurityScopedResource];
    // Read image metadata before decoding; a small compressed file may have huge dimensions.
    UIImage *image = nil;
    if (data.length > 0 && data.length <= 20 * 1024 * 1024) {
        CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
        if (source) {
            NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
            NSNumber *w = properties[(NSString *)kCGImagePropertyPixelWidth];
            NSNumber *h = properties[(NSString *)kCGImagePropertyPixelHeight];
            double width = w.doubleValue, height = h.doubleValue;
            if (width > 0 && height > 0 && width * height <= 16000000.0) {
                NSDictionary *options = @{
                    (NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                    (NSString *)kCGImageSourceCreateThumbnailWithTransform: @YES,
                    (NSString *)kCGImageSourceThumbnailMaxPixelSize: @1024,
                    (NSString *)kCGImageSourceShouldCacheImmediately: @YES
                };
                CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
                if (thumbnail) {
                    image = [UIImage imageWithCGImage:thumbnail];
                    CGImageRelease(thumbnail);
                }
            }
            CFRelease(source);
        }
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
