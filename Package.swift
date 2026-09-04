// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Cadence",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "CadenceCore", targets: ["CadenceCore"]),
    .executable(name: "Cadence", targets: ["Cadence"]),
  ],
  targets: [
    .target(name: "CadenceCore"),
    .executableTarget(name: "Cadence", dependencies: ["CadenceCore"]),
    .testTarget(name: "CadenceCoreTests", dependencies: ["CadenceCore"]),
  ]
)
