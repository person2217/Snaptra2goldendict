// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "GoldenDictLite", platforms: [.macOS(.v14)], products: [.executable(name: "GoldenDictLite", targets: ["GoldenDictLite"])], targets: [.executableTarget(name: "GoldenDictLite", swiftSettings: [.swiftLanguageMode(.v5)]), .testTarget(name: "GoldenDictLiteTests", dependencies: ["GoldenDictLite"], swiftSettings: [.swiftLanguageMode(.v5)])])
