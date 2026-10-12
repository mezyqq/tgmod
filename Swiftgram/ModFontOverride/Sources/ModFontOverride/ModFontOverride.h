#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// App-wide font replacement. On +load it reads the selected family from
// NSUserDefaults ("mod.font.family"), registers imported font files and swizzles
// +[UIFont systemFontOfSize:...] so that every system font request returns the
// selected family. A change of the family takes effect after restart.
@interface ModFontOverride : NSObject

// YES when a custom family is selected and installed for this launch.
+ (BOOL)isActive;

// Font of the active family with the closest weight, nil when inactive.
+ (nullable UIFont *)fontWithSize:(CGFloat)size weight:(UIFontWeight)weight italic:(BOOL)italic;

// Sorted family names installed on the device plus imported ones.
+ (NSArray<NSString *> *)availableFamilies;

// Family names that came from imported files.
+ (NSArray<NSString *> *)importedFamilies;

// Copies a .ttf/.otf/.ttc file into the app storage and registers it.
// Returns the family name of the first font in the file, nil on failure.
+ (nullable NSString *)importFontFileAtURL:(NSURL *)url;

// Removes an imported family (its files) from the storage.
+ (void)removeImportedFamily:(NSString *)family;

@end

NS_ASSUME_NONNULL_END
