// Contact sheet of stills, each labelled with its filename:
//   swift tools/capture/montage.swift sheet.png <cols> <cellWidth> a.png b.png ...
import AppKit
let a = CommandLine.arguments
let out = a[1], cols = Int(a[2])!, cw = CGFloat(Int(a[3])!)
let files = Array(a[4...])
let imgs = files.map { NSImage(contentsOfFile: $0)! }
let ch = cw * imgs[0].size.height / imgs[0].size.width
let rows = (imgs.count + cols - 1) / cols
let size = NSSize(width: cw * CGFloat(cols), height: ch * CGFloat(rows))
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
for (i, img) in imgs.enumerated() {
  let x = CGFloat(i % cols) * cw, y = size.height - CGFloat(i / cols + 1) * ch
  img.draw(in: NSRect(x: x, y: y, width: cw, height: ch))
  (files[i] as NSString).lastPathComponent.draw(at: NSPoint(x: x + 6, y: y + 6), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: NSColor.yellow])
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
