// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeshMindInference",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "MeshMindInference", targets: ["MeshMindInference"]),
    ],
    targets: [
        .target(
            name: "MeshMindInference",
            dependencies: ["LlamaFramework"],
            path: "Sources/MeshMindInference"
        ),
        .binaryTarget(
            name: "LlamaFramework",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b5046/llama-b5046-xcframework.zip",
            checksum: "c19be78b5f00d8d29a25da41042cb7afa094cbf6280a225abe614b03b20029ab"
        ),
    ]
)
