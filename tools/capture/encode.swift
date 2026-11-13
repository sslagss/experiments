// Encode a frame sequence into a looping H.264 mp4, with an optional crossfade
// so the clip's end dissolves into its start.
// Usage (or use cut.sh): swift encode.swift <out.mp4> <W> <H> <bitrate> <fps> <xfadeFrames> <frame1> <frame2> ...
import AVFoundation
import AppKit

let a = CommandLine.arguments
let outURL = URL(fileURLWithPath: a[1])
let W = Int(a[2])!, H = Int(a[3])!, bitrate = Int(a[4])!, fps = Int32(a[5])!, xf = Int(a[6])!
let files = Array(a[7...])
precondition(files.count > 2 * xf, "clip too short for crossfade")
try? FileManager.default.removeItem(at: outURL)

func cg(_ path: String) -> CGImage {
    var r = NSRect.zero
    return NSImage(contentsOfFile: path)!.cgImage(forProposedRect: &r, context: nil, hints: nil)!
}

let writer = try! AVAssetWriter(outputURL: outURL, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: bitrate,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: Int(fps) * 2,
    ],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
])
writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)

// Output: the first xf frames blend the clip's tail into its head, then the
// untouched middle. The last output frame flows straight into the first on loop.
let n = files.count
var out = 0
for i in 0..<(n - xf) {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
    var pb: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
    let buf = pb!
    CVPixelBufferLockBaseAddress(buf, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: W, height: H, bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    ctx.interpolationQuality = .high
    let rect = CGRect(x: 0, y: 0, width: W, height: H)
    if i < xf {
        let t = CGFloat(i + 1) / CGFloat(xf + 1)   // 0 → tail, 1 → head
        ctx.draw(cg(files[n - xf + i]), in: rect)
        ctx.setAlpha(t)
        ctx.draw(cg(files[i]), in: rect)
        ctx.setAlpha(1)
    } else {
        ctx.draw(cg(files[i]), in: rect)
    }
    CVPixelBufferUnlockBaseAddress(buf, [])
    adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(out), timescale: fps))
    out += 1
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print(writer.status == .completed ? "wrote \(outURL.path): \(out) frames" : "failed: \(String(describing: writer.error))")
