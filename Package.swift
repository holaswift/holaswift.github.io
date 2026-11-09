// swift-tools-version:6.0
// hola Swift: the website, built in Swift.
//
//   HolaSwift  the shared logic (models, meetups, cards, sheet), without Foundation so it fits in WebAssembly
//   Generate   writes the team, the meetups and the sponsors into index.html:  swift run generate [--check]
//   Web        what runs in the browser, compiled to WebAssembly:              ./scripts/build-web.sh

import PackageDescription

let package = Package(
    name: "HolaSwift",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "generate", targets: ["Generate"]),
        .executable(name: "Web", targets: ["Web"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", exact: "0.61.0"),
    ],
    targets: [
        .target(name: "HolaSwift"),
        .executableTarget(name: "Generate", dependencies: ["HolaSwift"]),
        .executableTarget(
            name: "Web",
            dependencies: ["HolaSwift", .product(name: "JavaScriptKit", package: "JavaScriptKit")],
            swiftSettings: [.swiftLanguageMode(.v5)]   // JavaScript objects aren't Sendable
        ),
    ]
)
