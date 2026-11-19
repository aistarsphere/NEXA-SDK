// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "nexa_realtime",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "nexa-realtime", targets: ["nexa_realtime"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "nexa_realtime",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
