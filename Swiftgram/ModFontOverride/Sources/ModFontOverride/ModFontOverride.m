#import "ModFontOverride.h"

#import <objc/runtime.h>
#import <CoreText/CoreText.h>

static NSString * const ModFontFamilyKey = @"mod.font.family";

static BOOL gActive = NO;
// family name -> file URLs it came from
static NSMutableDictionary<NSString *, NSMutableArray<NSURL *> *> *gImported = nil;

// One concrete face of the active family.
@interface ModFontFace : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic) CGFloat weight;
@property (nonatomic) BOOL italic;
@end

@implementation ModFontFace
@end

static NSArray<ModFontFace *> *gFaces = nil;
static NSCache<NSString *, UIFont *> *gCache = nil;

static NSURL *ModFontStorageURL(void) {
    NSURL *base = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *url = [base URLByAppendingPathComponent:@"ModFonts" isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:nil];
    return url;
}

static NSArray<NSString *> *ModFontFamiliesInFile(NSURL *url) {
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    CFArrayRef descriptors = CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url);
    if (descriptors) {
        for (CFIndex i = 0; i < CFArrayGetCount(descriptors); i++) {
            CTFontDescriptorRef descriptor = (CTFontDescriptorRef)CFArrayGetValueAtIndex(descriptors, i);
            NSString *family = CFBridgingRelease(CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute));
            if (family.length != 0 && ![result containsObject:family]) {
                [result addObject:family];
            }
        }
        CFRelease(descriptors);
    }
    return result;
}

static void ModFontRegisterFile(NSURL *url) {
    CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, NULL);
    for (NSString *family in ModFontFamiliesInFile(url)) {
        NSMutableArray<NSURL *> *urls = gImported[family];
        if (urls == nil) {
            urls = [NSMutableArray array];
            gImported[family] = urls;
        }
        [urls addObject:url];
    }
}

static CGFloat ModFontWeightOfFont(UIFont *font) {
    NSDictionary *traits = [font.fontDescriptor objectForKey:UIFontDescriptorTraitsAttribute];
    NSNumber *weight = traits[UIFontWeightTrait];
    if (weight != nil) {
        return (CGFloat)weight.doubleValue;
    }
    NSString *name = font.fontName.lowercaseString;
    if ([name containsString:@"black"] || [name containsString:@"heavy"]) return UIFontWeightHeavy;
    if ([name containsString:@"extrabold"]) return UIFontWeightHeavy;
    if ([name containsString:@"semibold"] || [name containsString:@"demibold"]) return UIFontWeightSemibold;
    if ([name containsString:@"bold"]) return UIFontWeightBold;
    if ([name containsString:@"medium"]) return UIFontWeightMedium;
    if ([name containsString:@"light"]) return UIFontWeightLight;
    if ([name containsString:@"thin"]) return UIFontWeightThin;
    return UIFontWeightRegular;
}

static NSArray<ModFontFace *> *ModFontLoadFaces(NSString *family) {
    NSMutableArray<ModFontFace *> *faces = [NSMutableArray array];
    for (NSString *name in [UIFont fontNamesForFamilyName:family]) {
        UIFont *font = [UIFont fontWithName:name size:17.0];
        if (font == nil) {
            continue;
        }
        ModFontFace *face = [[ModFontFace alloc] init];
        face.name = name;
        face.weight = ModFontWeightOfFont(font);
        face.italic = (font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitItalic) != 0;
        [faces addObject:face];
    }
    return faces;
}

@implementation UIFont (ModFontOverride)

+ (UIFont *)mod_systemFontOfSize:(CGFloat)fontSize {
    UIFont *font = [ModFontOverride fontWithSize:fontSize weight:UIFontWeightRegular italic:NO];
    return font ?: [self mod_systemFontOfSize:fontSize];
}

+ (UIFont *)mod_systemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight {
    UIFont *font = [ModFontOverride fontWithSize:fontSize weight:weight italic:NO];
    return font ?: [self mod_systemFontOfSize:fontSize weight:weight];
}

+ (UIFont *)mod_boldSystemFontOfSize:(CGFloat)fontSize {
    UIFont *font = [ModFontOverride fontWithSize:fontSize weight:UIFontWeightBold italic:NO];
    return font ?: [self mod_boldSystemFontOfSize:fontSize];
}

+ (UIFont *)mod_italicSystemFontOfSize:(CGFloat)fontSize {
    UIFont *font = [ModFontOverride fontWithSize:fontSize weight:UIFontWeightRegular italic:YES];
    return font ?: [self mod_italicSystemFontOfSize:fontSize];
}

@end

static void ModFontSwizzle(SEL original, SEL replacement) {
    Class metaClass = object_getClass([UIFont class]);
    Method originalMethod = class_getInstanceMethod(metaClass, original);
    Method replacementMethod = class_getInstanceMethod(metaClass, replacement);
    if (originalMethod != NULL && replacementMethod != NULL) {
        method_exchangeImplementations(originalMethod, replacementMethod);
    }
}

@implementation ModFontOverride

+ (void)load {
    gImported = [NSMutableDictionary dictionary];
    gCache = [[NSCache alloc] init];

    NSArray<NSURL *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:ModFontStorageURL() includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    for (NSURL *url in files) {
        ModFontRegisterFile(url);
    }

    NSString *family = [[NSUserDefaults standardUserDefaults] stringForKey:ModFontFamilyKey];
    if (family.length == 0) {
        return;
    }
    NSArray<ModFontFace *> *faces = ModFontLoadFaces(family);
    if (faces.count == 0) {
        return;
    }
    gFaces = faces;
    gActive = YES;

    ModFontSwizzle(@selector(systemFontOfSize:), @selector(mod_systemFontOfSize:));
    ModFontSwizzle(@selector(systemFontOfSize:weight:), @selector(mod_systemFontOfSize:weight:));
    ModFontSwizzle(@selector(boldSystemFontOfSize:), @selector(mod_boldSystemFontOfSize:));
    ModFontSwizzle(@selector(italicSystemFontOfSize:), @selector(mod_italicSystemFontOfSize:));
}

+ (BOOL)isActive {
    return gActive;
}

+ (UIFont *)fontWithSize:(CGFloat)size weight:(UIFontWeight)weight italic:(BOOL)italic {
    if (!gActive) {
        return nil;
    }
    NSString *key = [NSString stringWithFormat:@"%.2f_%.3f_%d", size, weight, italic ? 1 : 0];
    UIFont *cached = [gCache objectForKey:key];
    if (cached != nil) {
        return cached;
    }

    ModFontFace *best = nil;
    CGFloat bestScore = CGFLOAT_MAX;
    for (ModFontFace *face in gFaces) {
        CGFloat score = fabs(face.weight - weight);
        if (face.italic != italic) {
            score += 10.0;
        }
        if (score < bestScore) {
            bestScore = score;
            best = face;
        }
    }
    UIFont *font = best != nil ? [UIFont fontWithName:best.name size:size] : nil;
    if (font == nil) {
        return nil;
    }
    if (italic && !best.italic) {
        UIFontDescriptor *descriptor = [font.fontDescriptor fontDescriptorWithSymbolicTraits:font.fontDescriptor.symbolicTraits | UIFontDescriptorTraitItalic];
        if (descriptor != nil) {
            font = [UIFont fontWithDescriptor:descriptor size:size];
        }
    }
    [gCache setObject:font forKey:key];
    return font;
}

+ (NSArray<NSString *> *)availableFamilies {
    NSMutableSet<NSString *> *families = [NSMutableSet setWithArray:[UIFont familyNames]];
    [families addObjectsFromArray:gImported.allKeys];
    return [families.allObjects sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

+ (NSArray<NSString *> *)importedFamilies {
    return [gImported.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

+ (NSString *)importFontFileAtURL:(NSURL *)url {
    BOOL accessing = [url startAccessingSecurityScopedResource];
    NSURL *destination = [ModFontStorageURL() URLByAppendingPathComponent:url.lastPathComponent];
    [[NSFileManager defaultManager] removeItemAtURL:destination error:nil];
    BOOL copied = [[NSFileManager defaultManager] copyItemAtURL:url toURL:destination error:nil];
    if (accessing) {
        [url stopAccessingSecurityScopedResource];
    }
    if (!copied) {
        return nil;
    }
    NSArray<NSString *> *families = ModFontFamiliesInFile(destination);
    if (families.count == 0) {
        [[NSFileManager defaultManager] removeItemAtURL:destination error:nil];
        return nil;
    }
    ModFontRegisterFile(destination);
    return families.firstObject;
}

+ (void)removeImportedFamily:(NSString *)family {
    for (NSURL *url in gImported[family]) {
        CTFontManagerUnregisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, NULL);
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    }
    [gImported removeObjectForKey:family];
}

@end
