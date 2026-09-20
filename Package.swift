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
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
        .testTarget(name: "LivingFoldersCoreTests", dependencies: ["LivingFoldersCore"]),
    ]
)
