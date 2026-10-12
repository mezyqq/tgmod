load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ModPersonalBots",
    module_name = "ModPersonalBots",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Swiftgram/ModSettings:ModSettings",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
