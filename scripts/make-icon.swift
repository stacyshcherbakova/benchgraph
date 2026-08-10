// Generates the BenchGraph app icon as an .iconset directory of PNGs.
//
// The icon is drawn in code (CoreGraphics) so the repo needs no binary design
// assets and the icon is reproducible: an indigo squircle (the app's brand
// accent) carrying three descending bars under a significance bracket and an
// asterisk.
//
// The bracket is the point. A bar chart alone is the most generic icon on the
// platform; a bracket with a star over it is a *statistical figure*, which is
// what the app makes. It also survives being small — the bars stay crisp at
// 32px and the asterisk degrades to a dot rather than to mush.
//
// An earlier version drew a dose-response sigmoid with data points ringed in
// the background colour. The rings chopped the curve into a dashed line at
// 32px and the whole mark turned to noise; solid shapes are what read small.
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

    let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)

    // Three descending bars sharing a baseline. Solid rectangles are the most
    // robust thing to draw small, so they carry the icon at 16 and 32 px.
    ctx.setFillColor(white)
    let heights: [CGFloat] = [430, 296, 178]
    let barW: CGFloat = 158, gap: CGFloat = 66
    let spanW = 3 * barW + 2 * gap
    let baseY: CGFloat = 232
    var x = 512 - spanW / 2
    for h in heights {
        ctx.fill(CGRect(x: x, y: baseY, width: barW, height: h))
        x += barW + gap
    }

    // Significance bracket spanning the outer bars, with downward ticks.
    let leftX = 512 - spanW / 2 + barW / 2
    let rightX = 512 + spanW / 2 - barW / 2
    let bracketY: CGFloat = 730
    ctx.setStrokeColor(white)
    ctx.setLineWidth(28)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: leftX, y: bracketY - 44))
    ctx.addLine(to: CGPoint(x: leftX, y: bracketY))
    ctx.addLine(to: CGPoint(x: rightX, y: bracketY))
    ctx.addLine(to: CGPoint(x: rightX, y: bracketY - 44))
    ctx.strokePath()

    // Asterisk: three crossing strokes. Reads as a star large, as a dot small.
    // Offset clears the bracket: radius + half the stroke width + a gap.
    let starR: CGFloat = 46
    let starY = bracketY + starR + 17 + 22
    ctx.setLineWidth(34)
    ctx.beginPath()
    for k in 0..<3 {
        let a = CGFloat(k) * .pi / 3 + .pi / 2
        ctx.move(to: CGPoint(x: 512 - cos(a) * starR, y: starY - sin(a) * starR))
        ctx.addLine(to: CGPoint(x: 512 + cos(a) * starR, y: starY + sin(a) * starR))
    }
    ctx.strokePath()

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
