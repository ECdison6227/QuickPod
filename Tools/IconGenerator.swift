#!/usr/bin/env swift
// IconGenerator.swift - 生成 QuickPod 图标
// 纯白背景 + 大黑色闪电 + 右下角字母 C

import AppKit
import Foundation

let toolsDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
let projectDir = toolsDir.deletingLastPathComponent()
let outputPath = projectDir
    .appendingPathComponent("Sources/QuickPod/AppIcon.icns")
    .path

// Icons 需要的尺寸
let sizes: [(CGFloat, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let scale = size / 1024.0

    // 背景圆角矩形 - 纯白
    let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: 2 * scale, dy: 2 * scale),
                               xRadius: 224 * scale, yRadius: 224 * scale)
    NSColor.white.setFill()
    bgPath.fill()

    // 轻微边框
    NSColor(white: 0.9, alpha: 0.3).setStroke()
    bgPath.lineWidth = 4 * scale
    bgPath.stroke()

    // 黑色大闪电（主视觉）
    drawLightningBolt(in: rect, scale: scale)

    // 右下角的 C 标识
    drawLetterC(in: rect, scale: scale)

    image.unlockFocus()
    return image
}

func drawLightningBolt(in rect: NSRect, scale: CGFloat) {
    let cx = rect.midX
    let cy = rect.midY + 2 * scale

    let path = NSBezierPath()
    path.move(to: NSPoint(x: cx + 140 * scale, y: cy + 405 * scale))
    path.line(to: NSPoint(x: cx - 255 * scale, y: cy - 10 * scale))
    path.line(to: NSPoint(x: cx - 76 * scale, y: cy - 10 * scale))
    path.line(to: NSPoint(x: cx - 190 * scale, y: cy - 405 * scale))
    path.line(to: NSPoint(x: cx + 288 * scale, y: cy - 72 * scale))
    path.line(to: NSPoint(x: cx + 84 * scale, y: cy - 72 * scale))
    path.line(to: NSPoint(x: cx + 215 * scale, y: cy + 190 * scale))
    path.line(to: NSPoint(x: cx + 18 * scale, y: cy + 190 * scale))
    path.close()

    NSColor.black.setFill()
    path.fill()
}

func drawLetterC(in rect: NSRect, scale: CGFloat) {
    let fontSize = max(8, 135 * scale)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor.black
    ]
    let text = "C" as NSString
    let textSize = text.size(withAttributes: attributes)
    let origin = NSPoint(
        x: rect.maxX - 260 * scale,
        y: rect.minY + 150 * scale
    )
    let drawRect = NSRect(origin: origin, size: textSize)
    text.draw(in: drawRect, withAttributes: attributes)
}

// 生成所有尺寸并保存
let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("quickpod_icons")
try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

for (size, name) in sizes {
    let image = drawIcon(size: size)

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("  错误: 无法生成 \(size)x\(size)")
        continue
    }

    let fileURL = tempDir.appendingPathComponent("\(name).png")
    try? png.write(to: fileURL)
    print("  已生成: \(name).png (\(Int(size))x\(Int(size)))")
}

// 使用 iconutil 生成 .icns
let iconsetDir = tempDir.deletingLastPathComponent()
    .appendingPathComponent("quickpod.iconset")
try? FileManager.default.removeItem(at: iconsetDir) // 清理
try? FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

// 重命名为 iconset 需要的名称
let iconNameMap: [(String, String)] = [
    ("icon_16x16.png", "icon_16x16.png"),
    ("icon_16x16@2x.png", "icon_16x16@2x.png"),
    ("icon_32x32.png", "icon_32x32.png"),
    ("icon_32x32@2x.png", "icon_32x32@2x.png"),
    ("icon_128x128.png", "icon_128x128.png"),
    ("icon_128x128@2x.png", "icon_128x128@2x.png"),
    ("icon_256x256.png", "icon_256x256.png"),
    ("icon_256x256@2x.png", "icon_256x256@2x.png"),
    ("icon_512x512.png", "icon_512x512.png"),
    ("icon_512x512@2x.png", "icon_512x512@2x.png"),
]

for (src, dest) in iconNameMap {
    let srcURL = tempDir.appendingPathComponent(src)
    let destURL = iconsetDir.appendingPathComponent(dest)
    if FileManager.default.fileExists(atPath: srcURL.path) {
        try? FileManager.default.copyItem(at: srcURL, to: destURL)
    }
}

// 调用 iconutil
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", outputPath]
try? process.run()
process.waitUntilExit()

// 清理
try? FileManager.default.removeItem(at: tempDir)
try? FileManager.default.removeItem(at: iconsetDir)

if process.terminationStatus == 0 {
    print("\n  AppIcon.icns 已生成: \(outputPath)")
} else {
    print("\n  错误: iconutil 失败")
    exit(1)
}
