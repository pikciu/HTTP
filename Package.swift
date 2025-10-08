// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: .http,
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: .http,
            targets: [
                .http,
            ]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: .http,
            dependencies: []
        ),
        .testTarget(
            name: "HTTPTests",
            dependencies: [
                .targetItem(name: .http, condition: nil)
            ]
        ),
    ]
)

extension String {
    static let http = "HTTP"
}
