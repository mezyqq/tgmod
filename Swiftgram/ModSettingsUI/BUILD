load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ModSettingsUI",
    module_name = "ModSettingsUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Swiftgram/ModSettings:ModSettings",
        "//Swiftgram/ModFontOverride:ModFontOverride",
        "//Swiftgram/ModTypingAnimation:ModTypingAnimation",
        "//Swiftgram/ModVoice:ModVoice",
        "//Swiftgram/ModFaceMask:ModFaceMask",
    ],
    visibility = [
        "//visibility:public",
    ],
)
