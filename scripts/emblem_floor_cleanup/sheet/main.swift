import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// usage: [CH=cellHeight] sheet out.png cols cellWidth bgHex files...   (contact sheet over a solid canvas)
let a = CommandLine.arguments
let out = a[1]; let cols = Int(a[2])!; let cell = Int(a[3])!
let hex = UInt32(a[4], radix: 16)!
let files = Array(a[5...])
let rows = (files.count + cols - 1) / cols
let ch = Int(ProcessInfo.processInfo.environment["CH"] ?? "") ?? cell
let W = cols * cell, H = rows * ch
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setFillColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
ctx.interpolationQuality = .high
for (i, f) in files.enumerated() {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: f) as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
    let c = i % cols, r = i / cols
    let sc = min(Double(cell) / Double(img.width), Double(ch) / Double(img.height))
    ctx.draw(img, in: CGRect(x: Double(c * cell), y: Double(H - (r + 1) * ch), width: Double(img.width) * sc, height: Double(img.height) * sc))
}
let dst = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dst, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dst)
