// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Recap",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Recap",
            path: "Sources/Recap",
            resources: [
                .copy("../../Resources/Info.plist"),
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
            ],
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ImageIO"),
                .linkedFramework("CoreImage"),
                .linkedFramework("UniformTypeIdentifiers"),
            ]
        )
    ]
)
