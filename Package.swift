// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Focus",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Focus", targets: ["Focus"])
    ],
    targets: [
        .executableTarget(
            name: "Focus",
            path: "Focus/Sources"
        )
    ]
)
