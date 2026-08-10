// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Inface",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Inface", targets: ["InfaceApp"]),
        .executable(name: "InfaceTests", targets: ["InfaceTestRunner"]),
        .library(name: "InfaceCore", targets: ["InfaceCore"])
    ],
    targets: [
        .target(
            name: "InfaceCore",
            path: "Sources/InfaceCore",
            linkerSettings: [
                .linkedFramework("EventKit"),
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "InfaceApp",
            dependencies: ["InfaceCore"],
            path: "Sources/InfaceApp",
            exclude: ["Info.plist"]
        ),
        .executableTarget(
            name: "InfaceTestRunner",
            dependencies: ["InfaceCore"],
            path: "Sources/InfaceTestRunner"
        )
    ]
)
