// Makes the small round faces (assets/caras/) from the 800 × 1000 team photos (assets/equipo/).
//
//   swift scripts/caras.swift                       every photo in assets/equipo/
//   swift scripts/caras.swift assets/equipo/x.webp  only those
//
// The browser shrinks a large photo to 30–90px badly (worse inside a card turned in 3D), and the 4:5 framing leaves the
// face tiny in a circle: so each face is its own file, framed on the face, scaled down here with a good filter.
// macOS only (Vision finds the face) and needs cwebp (brew install webp).
import AppKit
import CoreImage
import Vision

let size = 256          // about 3× the largest circle (88px on a session with one talk)
let faceShare = 0.48    // the face's width over the side of the square: the head and a bit of neck, no shoulders

let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let output = root.appending(path: "assets/caras")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let inputs = CommandLine.arguments.count > 1
    ? CommandLine.arguments.dropFirst().map { URL(filePath: $0, relativeTo: root) }
    : try FileManager.default.contentsOfDirectory(at: root.appending(path: "assets/equipo"), includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "webp" }.sorted { $0.path < $1.path }

var failed = false
for url in inputs {
    guard let image = CIImage(contentsOf: url) else { print("✗ \(url.lastPathComponent): no se puede leer"); failed = true; continue }
    let w = image.extent.width, h = image.extent.height
    let request = VNDetectFaceRectanglesRequest()
    try VNImageRequestHandler(ciImage: image).perform([request])
    // the largest face, in case someone is in the background
    guard let found = (request.results ?? []).max(by: { $0.boundingBox.width < $1.boundingBox.width }) else {
        print("✗ \(url.lastPathComponent): no encuentra la cara"); failed = true; continue
    }
    let face = found.boundingBox, yaw = CGFloat(found.yaw?.doubleValue ?? 0)
    // Vision boxes only the face: go up for the hair and, in profile, open up and move towards the back of the head
    let side = min(face.width * w / faceShare * (1 + abs(yaw) * 0.5), w, h)
    let cx = (face.midX - yaw * face.width * 0.4) * w, cy = (face.midY + face.height * 0.15) * h
    let crop = CGRect(x: min(max(cx - side / 2, 0), w - side), y: min(max(cy - side / 2, 0), h - side), width: side, height: side)

    let scale = CGFloat(size) / side
    let lanczos = CIFilter(name: "CILanczosScaleTransform")!
    lanczos.setValue(image.cropped(to: crop).transformed(by: .init(translationX: -crop.minX, y: -crop.minY)), forKey: kCIInputImageKey)
    lanczos.setValue(scale, forKey: kCIInputScaleKey)
    lanczos.setValue(1.0, forKey: kCIInputAspectRatioKey)
    let small = lanczos.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: size, height: size))

    let png = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".png")
    defer { try? FileManager.default.removeItem(at: png) }
    try CIContext().writePNGRepresentation(of: small, to: png, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)

    let target = output.appending(path: url.deletingPathExtension().lastPathComponent + ".webp")
    let cwebp = Process()
    cwebp.executableURL = URL(filePath: "/usr/bin/env")
    cwebp.arguments = ["cwebp", "-quiet", "-q", "85", "-metadata", "none", png.path, "-o", target.path]
    try cwebp.run(); cwebp.waitUntilExit()
    if cwebp.terminationStatus != 0 { print("✗ \(url.lastPathComponent): cwebp ha fallado (brew install webp)"); failed = true; continue }
    print("✓ assets/caras/\(target.lastPathComponent)")
}
exit(failed ? 1 : 0)
