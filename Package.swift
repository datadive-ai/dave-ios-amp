// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Datadive-iOS-AMP",
    platforms: [
        .iOS(.v10),
        .tvOS(.v9),
        .macOS(.v10_10)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Datadive-iOS-AMP",
            targets: ["Datadive-iOS-AMP"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Datadive-iOS-AMP",
            dependencies: [],
            path: "Sources/Datadive-iOS-AMP",
            exclude: [],
            resources: [
                .process("Resources/ComodoRsaDomainValidationCA.der")],
            publicHeadersPath: "."),
        .testTarget(
            name: "Datadive-iOS-AMPTests",
            dependencies: ["Datadive-iOS-AMP"]),
    ]
)
