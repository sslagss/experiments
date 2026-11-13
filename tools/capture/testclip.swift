// Generates a seamless 4s test-pattern loop (960x384, 5:2) as H.264 mp4.
// Usage: swift tools/capture/testclip.swift previews/placeholder.mp4
import AVFoundation
import CoreGraphics
import CoreText
import Foundation

let W = 960, H = 384, FPS: Int32 = 30, SECONDS = 4
let frames = Int(FPS) * SECONDS
let outURL = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "placeholder.mp4")
try? FileManager.default.removeItem(at: outURL)

let writer = try! AVAssetWriter(outputURL: outURL, fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 500_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: Int(FPS),
    ],
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func drawText(_ ctx: CGContext, _ s: String, x: CGFloat, y: CGFloat, size: CGFloat, color: CGColor, bold: Bool = true, tracking: CGFloat = 0) {
    let font = CTFontCreateWithName((bold ? "HelveticaNeue-Bold" : "Menlo-Regular") as CFString, size, nil)
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        NSAttributedString.Key(kCTKernAttributeName as String): tracking,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: attrs))
    ctx.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, ctx)
}

let bars: [CGColor] = [rgb(192,192,192), rgb(192,192,0), rgb(0,192,192), rgb(0,192,0), rgb(192,0,192), rgb(192,0,0), rgb(0,0,192)]

for i in 0..<frames {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
    let t = CGFloat(i) / CGFloat(frames) // 0..1, loops seamlessly
    var pb: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
    let buf = pb!
    CVPixelBufferLockBaseAddress(buf, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: W, height: H, bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    // CoreGraphics origin is bottom-left.
    ctx.setFillColor(rgb(17, 17, 17)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

    // faint grid
    ctx.setStrokeColor(rgb(255, 255, 255, 0.06)); ctx.setLineWidth(1)
    for gx in stride(from: 0, through: W, by: 48) { ctx.move(to: CGPoint(x: gx, y: 0)); ctx.addLine(to: CGPoint(x: gx, y: H)) }
    for gy in stride(from: 0, through: H, by: 48) { ctx.move(to: CGPoint(x: 0, y: gy)); ctx.addLine(to: CGPoint(x: W, y: gy)) }
    ctx.strokePath()

    // colour bars strip along the bottom
    let barW = CGFloat(W) / CGFloat(bars.count)
    for (k, c) in bars.enumerated() {
        ctx.setFillColor(c.copy(alpha: 0.85)!); ctx.fill(CGRect(x: CGFloat(k) * barW, y: 0, width: barW + 1, height: 28))
    }

    // scan beam sweeping left to right with a soft trail
    let beamX = -120 + t * CGFloat(W + 240)
    for s in 0..<40 {
        let a = 0.22 * (1 - CGFloat(s) / 40)
        ctx.setFillColor(rgb(255, 255, 255, a * 0.35))
        ctx.fill(CGRect(x: beamX - CGFloat(s) * 3, y: 28, width: 3, height: CGFloat(H - 28)))
    }
    ctx.setFillColor(rgb(255, 255, 255, 0.9)); ctx.fill(CGRect(x: beamX, y: 28, width: 2, height: CGFloat(H - 28)))

    // pulsing centre ring
    let pulse = 0.5 + 0.5 * sin(t * 2 * .pi)
    let r = 46 + 10 * pulse
    ctx.setStrokeColor(rgb(255, 255, 255, 0.25 + 0.35 * pulse)); ctx.setLineWidth(2)
    ctx.strokeEllipse(in: CGRect(x: CGFloat(W) / 2 - r, y: CGFloat(H) / 2 + 14 - r, width: r * 2, height: r * 2))
    ctx.move(to: CGPoint(x: CGFloat(W) / 2 - 90, y: CGFloat(H) / 2 + 14)); ctx.addLine(to: CGPoint(x: CGFloat(W) / 2 + 90, y: CGFloat(H) / 2 + 14))
    ctx.move(to: CGPoint(x: CGFloat(W) / 2, y: CGFloat(H) / 2 + 14 - 90)); ctx.addLine(to: CGPoint(x: CGFloat(W) / 2, y: CGFloat(H) / 2 + 14 + 90))
    ctx.setStrokeColor(rgb(255, 255, 255, 0.18)); ctx.setLineWidth(1); ctx.strokePath()

    // labels
    drawText(ctx, "PREVIEW", x: 36, y: CGFloat(H) - 66, size: 34, color: rgb(255, 255, 255, 0.92), tracking: 6)
    drawText(ctx, "capture coming soon", x: 38, y: CGFloat(H) - 96, size: 16, color: rgb(255, 255, 255, 0.5), bold: false)
    let frame = i % Int(FPS), sec = i / Int(FPS)
    drawText(ctx, String(format: "00:00:%02d:%02d", sec, frame), x: CGFloat(W) - 190, y: CGFloat(H) - 60, size: 18, color: rgb(255, 255, 255, 0.6), bold: false)
    // blinking rec dot
    if (i / 15) % 2 == 0 {
        ctx.setFillColor(rgb(230, 60, 50)); ctx.fillEllipse(in: CGRect(x: CGFloat(W) - 216, y: CGFloat(H) - 61, width: 14, height: 14))
    }

    CVPixelBufferUnlockBaseAddress(buf, [])
    adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: FPS))
}

input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print(writer.status == .completed ? "wrote \(outURL.path)" : "failed: \(String(describing: writer.error))")
