// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LivingFolders",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "LivingFoldersCore"),
        .executableTarget(
            name: "LivingFolders",
            dependencies: ["LivingFoldersCore"],
            resources: [.copy("DemoFiles")],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
        .testTarget(name: "LivingFoldersCoreTests", dependencies: ["LivingFoldersCore"]),
        .testTarget(name: "LivingFoldersTests", dependencies: ["LivingFolders", "LivingFoldersCore"]),
    ]
)
