// Draws Apple's art safe areas (from the App Store Connect creative asset specs)
// onto copies of the header, universal and search art, so you can check the key
// artwork sits inside them.
//
//   swift AppStore/check_safe_areas.swift <output folder>

import AppKit

let safeAreas: [(file: String, rect: CGRect)] = [
    ("header.png", CGRect(x: 1097, y: 493, width: 1646, height: 661)),
    ("universal.png", CGRect(x: 1921, y: 660, width: 1402, height: 962)),
    ("search-results.png", CGRect(x: 836, y: 765, width: 2168, height: 1030)),
]
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
let art = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("upload/Header and Search Results")

for (file, rect) in safeAreas {
    guard let image = NSImage(contentsOf: art.appendingPathComponent(file)),
          let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("missing \(file)"); continue }
    let context = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
    // Apple gives the offset from the top left; Core Graphics counts from the bottom.
    let flipped = CGRect(x: rect.minX, y: CGFloat(cg.height) - rect.maxY, width: rect.width, height: rect.height)
    context.setStrokeColor(CGColor(red: 1, green: 0, blue: 1, alpha: 1))
    context.setLineWidth(12)
    context.stroke(flipped)
    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(file.replacingOccurrences(of: ".png", with: "-safe.png")))
    print("wrote \(file)")
}
