// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "WorkbenchLabs",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "WorkbenchLabsCore", targets: ["WorkbenchLabsCore"]),
    .executable(name: "WorkbenchLabs", targets: ["WorkbenchLabs"])
  ],
  targets: [
    .target(
      name: "WorkbenchLabsCore",
      resources: [
        .copy("Resources")
      ],
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("CoreImage"),
        .linkedFramework("ImageIO"),
        .linkedFramework("PDFKit")
      ]
    ),
    .executableTarget(
      name: "WorkbenchLabs",
      dependencies: ["WorkbenchLabsCore"],
      resources: [
        .copy("Resources")
      ],
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("Carbon"),
        .linkedFramework("WebKit")
      ]
    ),
    .testTarget(
      name: "WorkbenchLabsCoreTests",
      dependencies: ["WorkbenchLabsCore"],
      resources: [
        .copy("Fixtures")
      ]
    )
  ]
)
