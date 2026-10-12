load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ModFaceMask",
    module_name = "ModFaceMask",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Swiftgram/ModSettings:ModSettings",
    ],
    visibility = [
        "//visibility:public",
    ],
)
