#!/usr/bin/env swift
// macOS built-in CoreGraphics renders new vector geometry, no image editor/packages.
import AppKit
import Foundation

struct Icon: Decodable {
    let canvas: Double
    let background: String
    let foreground: String
    let polygons: [[[Double]]]
}
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let icon = try JSONDecoder().decode(Icon.self, from: Data(contentsOf: root.appendingPathComponent("tool/branding/icon.json")))
func color(_ hex: String) -> CGColor {
    let value = UInt32(hex, radix: 16)!
    return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [
        CGFloat((value >> 16) & 255) / 255, CGFloat((value >> 8) & 255) / 255,
        CGFloat(value & 255) / 255, 1])!
}
func write(_ data: Data, _ path: String) throws {
    let url = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
}
func png(_ size: Int, mask: String = "none") -> Data {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    if mask == "circle" { context.addEllipse(in: bounds); context.clip() }
    if mask == "rounded" {
        context.addPath(CGPath(roundedRect: bounds, cornerWidth: CGFloat(size) * 0.22, cornerHeight: CGFloat(size) * 0.22, transform: nil))
        context.clip()
    }
    context.setFillColor(color(icon.background)); context.fill(bounds)
    context.scaleBy(x: CGFloat(size) / icon.canvas, y: CGFloat(size) / icon.canvas)
    context.translateBy(x: 0, y: icon.canvas); context.scaleBy(x: 1, y: -1)
    context.setFillColor(color(icon.foreground))
    for polygon in icon.polygons {
        context.addLines(between: polygon.map { CGPoint(x: $0[0], y: $0[1]) })
        context.closePath()
    }
    context.fillPath()
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    // Apple catalog images must be opaque. Strip alpha for unmasked launcher assets.
    if mask == "none" {
        let opaque = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                               space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        opaque.draw(bitmap.cgImage!, in: bounds)
        return NSBitmapImageRep(cgImage: opaque.makeImage()!).representation(using: .png, properties: [:])!
    }
    return bitmap.representation(using: .png, properties: [:])!
}
for (density, size) in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)] {
    try write(png(size), "android/app/src/main/res/mipmap-\(density)/ic_launcher.png")
}
for platform in ["ios", "macos"] {
    let directory = "\(platform)/Runner/Assets.xcassets/AppIcon.appiconset"
    let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("\(directory)/Contents.json"))) as! [String: Any]
    for image in catalog["images"] as! [[String: String]] {
        let size = Double(image["size"]!.components(separatedBy: "x")[0])!
        let scale = Double(image["scale"]!.replacingOccurrences(of: "x", with: ""))!
        try write(png(Int(size * scale)), "\(directory)/\(image["filename"]!)")
    }
}
try write(png(32), "web/favicon.png")
for size in [192,512] {
    for name in ["Icon", "Icon-maskable"] { try write(png(size), "web/icons/\(name)-\(size).png") }
}
// ICO stores PNG payloads with an explicit little-endian directory for each size.
func le(_ value: Int, _ count: Int) -> Data { Data((0..<count).map { UInt8((value >> ($0 * 8)) & 255) }) }
let sizes = [16,32,48,64,128,256]
let payloads = sizes.map { png($0) }
var ico = le(0,2) + le(1,2) + le(sizes.count,2)
var offset = 6 + sizes.count * 16
for (index, size) in sizes.enumerated() {
    ico += Data([UInt8(size % 256), UInt8(size % 256), 0, 0]) + le(1,2) + le(32,2) + le(payloads[index].count,4) + le(offset,4)
    offset += payloads[index].count
}
for data in payloads { ico += data }
try write(ico, "windows/runner/resources/app_icon.ico")
let pathData = icon.polygons.map { polygon in
    polygon.enumerated().map { index, point in
        "\(index == 0 ? "M" : "L")\(point[0]),\(point[1])"
    }.joined(separator: " ") + " Z"
}.joined(separator: " ")
// 중앙 72dp를 원본 캔버스로 사용해 런처 마스크 적용 후 비례를 유지한다.
let viewport = icon.canvas * 1.5
let inset = icon.canvas * 0.25
let vector = """
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp" android:viewportWidth="\(viewport)" android:viewportHeight="\(viewport)">
  <group android:translateX="\(inset)" android:translateY="\(inset)">
    <path android:fillColor="#\(icon.foreground)" android:pathData="\(pathData)"/>
  </group>
</vector>

"""
try write(Data(vector.utf8), "android/app/src/main/res/drawable/ic_launcher_foreground.xml")
try write(Data(vector.replacingOccurrences(of: "#\(icon.foreground)", with: "#FFFFFF").utf8), "android/app/src/main/res/drawable/ic_launcher_monochrome.xml")
let notification = """
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp" android:viewportWidth="576" android:viewportHeight="576">
  <group android:translateX="-224" android:translateY="-224">
    <path android:fillColor="#FFFFFF" android:pathData="\(pathData)"/>
  </group>
</vector>

"""
try write(Data(notification.utf8), "android/app/src/main/res/drawable/ic_stat_3lines.xml")
try write(Data("<resources><color name=\"ic_launcher_background\">#\(icon.background)</color></resources>\n".utf8), "android/app/src/main/res/values/ic_launcher_colors.xml")
for version in [26,33] {
    let monochrome = version == 33 ? "  <monochrome android:drawable=\"@drawable/ic_launcher_monochrome\"/>\n" : ""
    let adaptive = """
    <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
      <background android:drawable="@color/ic_launcher_background"/>
      <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    \(monochrome)</adaptive-icon>

    """
    try write(Data(adaptive.utf8), "android/app/src/main/res/mipmap-anydpi-v\(version)/ic_launcher.xml")
}
for size in [48,192,1024] { try write(png(size), "tool/branding/previews/icon-\(size).png") }
for mask in ["circle","rounded"] { try write(png(192, mask: mask), "tool/branding/previews/adaptive-\(mask).png") }
print("Generated Android/iOS/macOS/web/Windows icons and adaptive previews from icon.json")
