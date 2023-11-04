// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "TafsirScrapingScript",
    dependencies: [
        .package(url: "https://github.com/tid-kijyun/Kanna.git", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "TafsirScrapingScript",
            dependencies: ["Kanna"]
        )
    ]
)



