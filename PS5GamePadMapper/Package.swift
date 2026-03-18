// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PS5GamePadMapper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "PS5GamePadMapper",
            targets: ["PS5GamePadMapper"]
        ),
        .library(
            name: "PS5GamePadMapperCore",
            targets: ["PS5GamePadMapperCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0")
    ],
    targets: [
        .executableTarget(
            name: "PS5GamePadMapper",
            dependencies: ["PS5GamePadMapperCore"],
            path: "Sources/App",
            resources: [
                .copy("../../Resources/Info.plist")
            ]
        ),
        .target(
            name: "PS5GamePadMapperCore",
            dependencies: [],
            path: "Sources/Core"
        ),
        .testTarget(
            name: "PS5GamePadMapperTests",
            dependencies: [
                "PS5GamePadMapperCore",
                "SwiftCheck"
            ],
            path: "Tests"
        )
    ]
)
