// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SoccerRefereeApp",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SoccerRefereeApp",
            targets: ["SoccerRefereeApp"]),
    ],
    targets: [
        .target(
            name: "SoccerRefereeApp",
            dependencies: []),
    ]
)