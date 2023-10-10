// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var platforms: [SupportedPlatform] = [
    .macOS(.v12),
    .iOS(.v15),
    .tvOS(.v15),
    .watchOS(.v8)
]

let package = Package(name: "UseCases",
                      platforms: platforms,
                      products: [
                          // Products define the executables and libraries a package produces, and make them
                          // visible to other packages.
                          .library(name: "UseCases",
                                   targets: ["UseCases"])
                      ],
                      dependencies: [
                          // Dependencies declare other packages that this package depends on.
                          .package(name: "Entities", path: "../Entities"),
                          .package(url: "https://github.com/protonpass/ios-pass-rust-core", exact: "0.1.1")
                      ],
                      targets: [
                          // Targets are the basic building blocks of a package. A target can define a module or a
                          // test suite.
                          // Targets can depend on other targets in this package, and on products in packages this
                          // package depends on.
                          .target(name: "UseCases",
                                  dependencies: [
                                      .product(name: "Entities", package: "Entities"),
                                      .product(name: "PassRustCore", package: "ios-pass-rust-core")
                                  ],
                                  resources: []),
                          .testTarget(name: "UseCasesTests",
                                      dependencies: ["UseCases"])
                      ])
