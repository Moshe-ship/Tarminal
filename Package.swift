// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tarminal",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.13.0")
    ],
    targets: [
        .executableTarget(
            name: "Tarminal",
            dependencies: ["SwiftTerm"],
            path: "Tarminal"
        )
    ]
)
