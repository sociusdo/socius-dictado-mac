// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SociusDictado",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "SociusDictado",
            path: "Sources/SociusDictado"
        )
    ]
)
