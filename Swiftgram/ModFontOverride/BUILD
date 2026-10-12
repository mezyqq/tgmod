
objc_library(
    name = "ModFontOverride",
    enable_modules = True,
    module_name = "ModFontOverride",
    srcs = glob([
        "Sources/ModFontOverride/*.m",
    ]),
    hdrs = glob([
        "Sources/ModFontOverride/*.h",
    ]),
    includes = [
      "Sources",
    ],
    sdk_frameworks = [
      "Foundation",
      "UIKit",
      "CoreText",
    ],
    alwayslink = True,
    visibility = [
        "//visibility:public",
    ],
)
