// Trims and scales a simulator recording into a small H.264 MP4 plus a poster PNG.
// usage: swift clip.swift in.mov out.mp4 poster.png start seconds width
import AVFoundation
import CoreImage
import AppKit

let a = CommandLine.arguments
let input = URL(fileURLWithPath: a[1]), output = URL(fileURLWithPath: a[2]), posterURL = URL(fileURLWithPath: a[3])
let start = Double(a[4])!, length = Double(a[5])!, width = Double(a[6])!
try? FileManager.default.removeItem(at: output)

let asset = AVURLAsset(url: input)
let track = asset.tracks(withMediaType: .video)[0]
let natural = track.naturalSize.applying(track.preferredTransform)
let source = CGSize(width: abs(natural.width), height: abs(natural.height))
let scale = width / source.width
let size = CGSize(width: (source.width * scale / 2).rounded() * 2, height: (source.height * scale / 2).rounded() * 2)
let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), duration: CMTime(seconds: length, preferredTimescale: 600))

let composition = AVMutableVideoComposition()
composition.renderSize = size
composition.frameDuration = CMTime(value: 1, timescale: 30)
let instruction = AVMutableVideoCompositionInstruction()
instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
layer.setTransform(track.preferredTransform.concatenating(CGAffineTransform(scaleX: scale, y: scale)), at: .zero)
instruction.layerInstructions = [layer]
composition.instructions = [instruction]

let reader = try AVAssetReader(asset: asset)
reader.timeRange = range
let out = AVAssetReaderVideoCompositionOutput(videoTracks: [track], videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
out.videoComposition = composition
reader.add(out)

let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
writer.shouldOptimizeForNetworkUse = true
let input2 = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: size.width, AVVideoHeightKey: size.height,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 1_400_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                      AVVideoMaxKeyFrameIntervalKey: 60, AVVideoAllowFrameReorderingKey: false]
])
input2.expectsMediaDataInRealTime = false
writer.add(input2)
reader.startReading()
writer.startWriting()
writer.startSession(atSourceTime: range.start)
let done = DispatchSemaphore(value: 0)
input2.requestMediaDataWhenReady(on: DispatchQueue(label: "w")) {
    while input2.isReadyForMoreMediaData {
        if let buffer = out.copyNextSampleBuffer() { input2.append(buffer) } else { input2.markAsFinished(); writer.endSession(atSourceTime: range.end); writer.finishWriting { done.signal() }; return }
    }
}
done.wait()
guard writer.status == .completed else { print("failed", writer.error as Any); exit(1) }

// Poster: the last frame, so a reduced-motion or paused view shows the finished state.
let generator = AVAssetImageGenerator(asset: AVURLAsset(url: output))
generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
let image = try generator.copyCGImage(at: CMTime(seconds: max(0, length - 0.1), preferredTimescale: 600), actualTime: nil)
let rep = NSBitmapImageRep(cgImage: image)
try rep.representation(using: .png, properties: [:])!.write(to: posterURL)
let bytes = (try FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int) ?? 0
print("\(output.lastPathComponent) \(Int(size.width))x\(Int(size.height)) \(bytes / 1024) KB")
