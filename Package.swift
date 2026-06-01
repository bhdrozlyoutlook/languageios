// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LanguageIOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "LanguageIOS", targets: ["LanguageIOS"])
    ],
    dependencies: [
        .package(url: "https://github.com/madebybowtie/FlagKit.git", from: "2.4.0")
    ],
    targets: [
        .target(
            name: "LanguageIOS",
            dependencies: [
                .product(name: "FlagKit", package: "FlagKit", condition: .when(platforms: [.iOS, .tvOS]))
            ]
        ),
        .testTarget(name: "LanguageIOSTests", dependencies: ["LanguageIOS"])
    ]
)
