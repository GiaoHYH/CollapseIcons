#!/usr/bin/env swift
//
// make_icon.swift — generates the CollapseIcons app icon as PNGs into an .iconset.
//
// Draws a macOS-style squircle with a light-blue gradient and a white
// double-chevron "«" collapse glyph. Pure CoreGraphics, no assets required.
//
// Usage: swift make_icon.swift <output.iconset dir>
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func makeIcon(size: Int, to url: URL) {
    let S = CGFloat(size)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.clear(CGRect(x: 0, y: 0, width: S, height: S))

    // Squircle background (macOS icon grid: ~82% of canvas, corner ≈ 0.2237 side).
    let inset = S * 0.09
    let rect = CGRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
    let radius = rect.width * 0.2237
    let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    // Vertical light-blue → blue gradient (CG origin is bottom-left).
    let colors = [
        CGColor(red: 0.44, green: 0.73, blue: 1.00, alpha: 1.0),
        CGColor(red: 0.16, green: 0.48, blue: 0.96, alpha: 1.0),
    ] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
    }

    // Faint top highlight for depth.
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
    ctx.fill(CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2))
    ctx.restoreGState()

    // White double-chevron "«" (collapse glyph).
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
    ctx.setLineWidth(S * 0.072)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    let cy = S / 2
    let h = S * 0.155   // chevron half-height
    let w = S * 0.125   // chevron arm width
    for off in [-0.085, 0.085] as [CGFloat] {   // two chevrons pointing left
        let cx = S / 2 + off * S
        ctx.move(to: CGPoint(x: cx + w, y: cy + h))
        ctx.addLine(to: CGPoint(x: cx - w, y: cy))
        ctx.addLine(to: CGPoint(x: cx + w, y: cy - h))
        ctx.strokePath()
    }

    guard let img = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { return }
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

// --- entry ---
guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write("usage: make_icon.swift <output.iconset dir>\n".data(using: .utf8)!)
    exit(1)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// (filename, pixel size) pairs required by iconutil.
let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]
for (name, px) in variants {
    makeIcon(size: px, to: outDir.appendingPathComponent(name))
    print("  \(name) (\(px)px)")
}
print("✓ iconset written: \(outDir.path)")
