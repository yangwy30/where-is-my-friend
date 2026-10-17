import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Straight (non-premultiplied) RGBA8 buffer.
struct Pix {
    var w: Int, h: Int
    var d: [UInt8]
    @inline(__always) func i(_ x: Int, _ y: Int) -> Int { (y * w + x) * 4 }
}

func loadPix(_ path: String) -> Pix {
    let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
    let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
    let w = img.width, h = img.height
    // Draw into premultiplied context with high-precision float to unpremultiply safely.
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    var f = [Float](repeating: 0, count: w * h * 4)
    let ctx = CGContext(data: &f, width: w, height: h, bitsPerComponent: 32, bytesPerRow: w * 16, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    var d = [UInt8](repeating: 0, count: w * h * 4)
    for p in 0..<(w * h) {
        let a = f[p * 4 + 3]
        d[p * 4 + 3] = UInt8(max(0, min(255, (a * 255).rounded())))
        if a > 0 {
            for c in 0..<3 { d[p * 4 + c] = UInt8(max(0, min(255, (f[p * 4 + c] / a * 255).rounded()))) }
        }
    }
    return Pix(w: w, h: h, d: d)
}

func savePix(_ p: Pix, _ path: String) {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let data = Data(p.d) as CFData
    let prov = CGDataProvider(data: data)!
    let img = CGImage(width: p.w, height: p.h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: p.w * 4, space: cs,
                      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: prov, decode: nil,
                      shouldInterpolate: false, intent: .defaultIntent)!
    let dst = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dst, img, nil)
    CGImageDestinationFinalize(dst)
}
