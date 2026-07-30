// Generates the BenchGraph app icon as an .iconset directory of PNGs.
//
// The icon is drawn in code (CoreGraphics) so the repo needs no binary design
// assets and the icon is reproducible: an indigo macOS-style squircle (the
// app's brand accent) with a white dose-response sigmoid and data points —
// the app's signature workflow.
//
// Usage:  swift scripts/make-icon.swift <output.iconset-dir>
// Then:   iconutil -c icns -o assets/AppIcon.icns <output.iconset-dir>

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

/// Draw the icon into a px × px bitmap. All geometry is authored in a
/// 1024-point canvas (bottom-left origin) and scaled down.
func drawIcon(px: Int) -> CGImage? {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(data: nil, width: px, height: px,
                              bitsPerComponent: 8, bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    let s = CGFloat(px) / 1024
    ctx.scaleBy(x: s, y: s)

    // Squircle plate with the standard macOS margin (~10% each side).
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    ctx.addPath(CGPath(roundedRect: plate, cornerWidth: 185, cornerHeight: 185, transform: nil))
    ctx.clip()

    // Indigo vertical gradient, brighter at the top.
    let top = CGColor(srgbRed: 0.494, green: 0.478, blue: 0.945, alpha: 1)  // #7E7AF1
    let bottom = CGColor(srgbRed: 0.278, green: 0.263, blue: 0.760, alpha: 1)  // #4743C2
    let gradient = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 512, y: 924),
                           end: CGPoint(x: 512, y: 100),
                           options: [])

    // Axis: an L from the top of the y-axis to the end of the x-axis.
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.5))
    ctx.setLineWidth(22)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 268, y: 752))
    ctx.addLine(to: CGPoint(x: 268, y: 312))
    ctx.addLine(to: CGPoint(x: 776, y: 312))
    ctx.strokePath()

    // Dose-response sigmoid.
    func sigmoidY(_ x: CGFloat) -> CGFloat {
        let t = (x - 528) / 78
        return 372 + 330 / (1 + exp(-t))
    }
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(46)
    ctx.beginPath()
    var first = true
    var x: CGFloat = 306
    while x <= 762 {
        let p = CGPoint(x: x, y: sigmoidY(x))
        if first { ctx.move(to: p); first = false } else { ctx.addLine(to: p) }
        x += 8
    }
    ctx.strokePath()

    // Data points, slightly off the curve so they read as measurements.
    let dots: [(x: CGFloat, dy: CGFloat)] = [(352, 16), (462, -18), (572, 20), (700, -14)]
    for d in dots {
        let c = CGPoint(x: d.x, y: sigmoidY(d.x) + d.dy)
        let r: CGFloat = 34
        // Indigo ring separates the dot from the curve where they overlap.
        ctx.setFillColor(bottom)
        ctx.fillEllipse(in: CGRect(x: c.x - r - 10, y: c.y - r - 10, width: 2 * (r + 10), height: 2 * (r + 10)))
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) -> Bool {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { return false }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest)
}

// MARK: - Main

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: swift make-icon.swift <output.iconset-dir>\n".utf8))
    exit(2)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

for spec in sizes {
    guard let image = drawIcon(px: spec.px),
          writePNG(image, to: outDir.appendingPathComponent(spec.name)) else {
        FileHandle.standardError.write(Data("error: failed to render \(spec.name)\n".utf8))
        exit(1)
    }
}
print("Wrote \(sizes.count) PNGs to \(outDir.path)")
