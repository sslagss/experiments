// Derive lighter assets from a finished preview clip (macOS AVFoundation, nothing to install).
//
//   swift derive.swift poster <in.mp4> <out.jpg> <seconds> <width> [quality=0.72]
//       a still at that moment, scaled to <width> (keeps the aspect)
//   swift derive.swift scale <in.mp4> <out.mp4> <width> <height> <bitrate>
//       the same frames re-encoded smaller (H.264), so the loop stays seamless
import AVFoundation
import AppKit

let a = CommandLine.arguments
func fail(_ m: String) -> Never { FileHandle.standardError.write((m + "\n").data(using: .utf8)!); exit(1) }
guard a.count >= 4 else { fail("usage: derive.swift poster|scale ...") }
let asset = AVURLAsset(url: URL(fileURLWithPath: a[2]))
let outURL = URL(fileURLWithPath: a[3])
try? FileManager.default.removeItem(at: outURL)

func scaled(_ img: CGImage, _ w: Int, _ h: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()!
}

switch a[1] {
case "poster":
    let secs = Double(a[4])!, width = Int(a[5])!, q = a.count > 6 ? Double(a[6])! : 0.72
    let gen = AVAssetImageGenerator(asset: asset)
    gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
    let img = try! gen.copyCGImage(at: CMTime(seconds: secs, preferredTimescale: 600), actualTime: nil)
    let h = Int((Double(width) * Double(img.height) / Double(img.width)).rounded())
    let rep = NSBitmapImageRep(cgImage: scaled(img, width, h))
    try! rep.representation(using: .jpeg, properties: [.compressionFactor: q, .progressive: true])!.write(to: outURL)
    print("wrote \(outURL.path) \(width)x\(h)")

case "scale":
    let W = Int(a[4])!, H = Int(a[5])!, bitrate = Int(a[6])!
    let track = asset.tracks(withMediaType: .video)[0]
    let reader = try! AVAssetReader(asset: asset)
    let rout = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB])
    reader.add(rout)
    let writer = try! AVAssetWriter(outputURL: outURL, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitrate,
                                          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                          AVVideoMaxKeyFrameIntervalKey: 60],
    ])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
    ])
    writer.add(input)
    reader.startReading(); writer.startWriting(); writer.startSession(atSourceTime: .zero)
    var n = 0
    while let sb = rout.copyNextSampleBuffer(), let src = CMSampleBufferGetImageBuffer(sb) {
        let t = CMSampleBufferGetPresentationTimeStamp(sb)
        CVPixelBufferLockBaseAddress(src, .readOnly)
        let sctx = CGContext(data: CVPixelBufferGetBaseAddress(src), width: CVPixelBufferGetWidth(src), height: CVPixelBufferGetHeight(src),
                             bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(src), space: CGColorSpaceCreateDeviceRGB(),
                             bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        let img = sctx.makeImage()!
        CVPixelBufferUnlockBaseAddress(src, .readOnly)
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
        CVPixelBufferLockBaseAddress(pb!, [])
        let dctx = CGContext(data: CVPixelBufferGetBaseAddress(pb!), width: W, height: H, bitsPerComponent: 8,
                             bytesPerRow: CVPixelBufferGetBytesPerRow(pb!), space: CGColorSpaceCreateDeviceRGB(),
                             bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        dctx.interpolationQuality = .high
        dctx.draw(img, in: CGRect(x: 0, y: 0, width: W, height: H))
        CVPixelBufferUnlockBaseAddress(pb!, [])
        adaptor.append(pb!, withPresentationTime: t)
        n += 1
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    print(writer.status == .completed ? "wrote \(outURL.path): \(n) frames" : "failed: \(String(describing: writer.error))")

default:
    fail("unknown mode \(a[1])")
}
