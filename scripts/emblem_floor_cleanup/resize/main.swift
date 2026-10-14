import Foundation
import CoreGraphics
// usage: resize in.png out.png size   (high-quality square downscale, straight-alpha output)
let a = CommandLine.arguments
let src = loadPix(a[1]); let size = Int(a[3])!
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
// Premultiply into a float image so the resampler weights colour by coverage.
var f = [Float](repeating: 0, count: src.w * src.h * 4)
for k in 0..<(src.w * src.h) {
    let al = Float(src.d[k*4+3]) / 255
    for c in 0..<3 { f[k*4+c] = Float(src.d[k*4+c]) / 255 * al }
    f[k*4+3] = al
}
let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
let srcImg = f.withUnsafeMutableBytes { buf -> CGImage in
    CGContext(data: buf.baseAddress, width: src.w, height: src.h, bitsPerComponent: 32, bytesPerRow: src.w * 16, space: cs, bitmapInfo: info)!.makeImage()!
}
var o = [Float](repeating: 0, count: size * size * 4)
o.withUnsafeMutableBytes { buf in
    let ctx = CGContext(data: buf.baseAddress, width: size, height: size, bitsPerComponent: 32, bytesPerRow: size * 16, space: cs, bitmapInfo: info)!
    ctx.interpolationQuality = .high
    ctx.draw(srcImg, in: CGRect(x: 0, y: 0, width: size, height: size))
}
var out = Pix(w: size, h: size, d: [UInt8](repeating: 0, count: size * size * 4))
for k in 0..<(size * size) {
    let al = o[k*4+3]
    out.d[k*4+3] = UInt8(max(0, min(255, (al * 255).rounded())))
    if al > 0 { for c in 0..<3 { out.d[k*4+c] = UInt8(max(0, min(255, (o[k*4+c] / al * 255).rounded()))) } }
}
savePix(out, a[2])
