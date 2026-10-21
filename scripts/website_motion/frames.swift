import AVFoundation
import AppKit
let a = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: a[1])), out = a[2], fps = Double(a[3])!, width = Double(a[4])!
let g = AVAssetImageGenerator(asset: asset); g.maximumSize = CGSize(width: width, height: width * 3)
g.requestedTimeToleranceBefore = .zero; g.requestedTimeToleranceAfter = .zero
var i = 0, t = 0.0
while t < asset.duration.seconds - 0.05 {
  let img = try! g.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil)
  try! NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: String(format: "%@/%03d.png", out, i)))
  i += 1; t += 1 / fps
}
print(i, "frames")
