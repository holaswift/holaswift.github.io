// swift-tools-version:6.0
// hola Swift: la web, hecha en Swift.
//
//   HolaSwift  la lógica compartida (modelos, quedadas, tarjetas, hoja), sin Foundation para que quepa en WebAssembly
//   Generar    escribe el equipo, las quedadas y los patrocinadores en index.html:  swift run generar [--comprobar]
//   Web        lo que corre en el navegador, compilado a WebAssembly:              ./scripts/compilar-web.sh

import PackageDescription

let package = Package(
    name: "HolaSwift",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "generar", targets: ["Generar"]),
        .executable(name: "Web", targets: ["Web"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", exact: "0.61.0"),
    ],
    targets: [
        .target(name: "HolaSwift"),
        .executableTarget(name: "Generar", dependencies: ["HolaSwift"]),
        .executableTarget(
            name: "Web",
            dependencies: ["HolaSwift", .product(name: "JavaScriptKit", package: "JavaScriptKit")],
            swiftSettings: [.swiftLanguageMode(.v5)]   // los objetos de JavaScript no son Sendable
        ),
    ]
)
