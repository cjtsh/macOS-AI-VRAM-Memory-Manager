// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacAIMemoryManager",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MacAIMemoryManager", targets: ["MacAIMemoryManager"])],
    targets: [.executableTarget(name: "MacAIMemoryManager")]
)
