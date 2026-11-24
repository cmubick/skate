import AppKit

// Draws the Android launcher icon from the iOS icon (AppStore/icon/make_icon.swift).
//
// Android crops icons to a circle, squircle or square of the phone's choosing, from
// a 108 dp layer of which the middle 72 dp is shown. So the 32 x 32 pixel picture is
// drawn 64 dp wide in the middle, in whole screen pixels so it stays sharp, and its
// edges are stretched out to the sides: whatever shape the phone cuts, it cuts sky
// and street, not the skater.
//
// usage (from the repository root):
//   swift AppStore/icon/make_icon.swift /tmp/icon.png light
//   swift android/tools/icon/make_icons.swift /tmp/icon.png android/app/src/main/res
let args = CommandLine.arguments
let source = NSImage(contentsOfFile: args[1])!
let res = args[2]
let rep = NSBitmapImageRep(data: source.tiffRepresentation!)!
let grid = 32
let cell = rep.pixelsWide / grid
// The colour of each square of the 32 x 32 picture, top row first.
var colors: [[NSColor]] = (0..<grid).map { row in
    (0..<grid).map { column in rep.colorAt(x: column * cell + cell / 2, y: row * cell + cell / 2)! }
}

for (folder, density) in [("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2), ("xxhdpi", 3), ("xxxhdpi", 4)] as [(String, Double)] {
    let size = Int(108 * density)
    let square = Int(2 * density) // screen pixels per picture pixel: the picture is 64 dp
    let offset = (size - grid * square) / 2
    let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    for y in 0..<size {
        for x in 0..<size {
            let column = min(grid - 1, max(0, (x - offset) >= 0 ? (x - offset) / square : -1))
            let row = min(grid - 1, max(0, (y - offset) >= 0 ? (y - offset) / square : -1))
            out.setColor(colors[row][column], atX: x, y: y)
        }
    }
    let dir = "\(res)/mipmap-\(folder)"
    try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(dir)/ic_launcher_background.png"))
}
print("Wrote the launcher icons.")
