// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JustTodo",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "JustTodo", targets: ["JustTodo"])],
    targets: [
        .target(name: "TodoCore"),
        .executableTarget(name: "JustTodo", dependencies: ["TodoCore"], path: "Sources/EdgeTodo", resources: [.copy("Resources/Fonts")]),
        .testTarget(name: "TodoCoreTests", dependencies: ["TodoCore"])
    ]
)
