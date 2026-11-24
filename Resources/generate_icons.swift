import AppKit

func makeIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    
    // Background squircle / rounded rect (macOS icon standard shape)
    let cornerRadius = size * 0.2237
    let bgRect = rect.insetBy(dx: size * 0.05, dy: size * 0.05)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
    
    // Gradient: Emerald to deep forest green
    let grad = NSGradient(
        starting: NSColor(red: 0.08, green: 0.45, blue: 0.32, alpha: 1.0),
        ending: NSColor(red: 0.16, green: 0.70, blue: 0.46, alpha: 1.0)
    )
    grad?.draw(in: bgPath, angle: -45)
    
    // Subtle border highlight
    NSColor(white: 1.0, alpha: 0.2).setStroke()
    bgPath.lineWidth = size * 0.015
    bgPath.stroke()
    
    // Battery Body Outline
    let battWidth = size * 0.50
    let battHeight = size * 0.26
    let battX = (size - battWidth) / 2
    let battY = (size - battHeight) / 2 + (size * 0.03)
    let battRect = CGRect(x: battX, y: battY, width: battWidth, height: battHeight)
    let battPath = NSBezierPath(roundedRect: battRect, xRadius: size * 0.045, yRadius: size * 0.045)
    NSColor.white.setStroke()
    battPath.lineWidth = size * 0.035
    battPath.stroke()
    
    // Battery Terminal (right cap)
    let capWidth = size * 0.035
    let capHeight = size * 0.11
    let capX = battX + battWidth + (size * 0.01)
    let capY = battY + (battHeight - capHeight) / 2
    let capPath = NSBezierPath(roundedRect: CGRect(x: capX, y: capY, width: capWidth, height: capHeight),
                               xRadius: size * 0.012, yRadius: size * 0.012)
    NSColor.white.setFill()
    capPath.fill()
    
    // Battery Level Fill (Golden Amber 25% charge)
    let fillInset = size * 0.045
    let fillWidth = (battWidth - fillInset * 2) * 0.35
    let fillRect = CGRect(x: battX + fillInset, y: battY + fillInset, width: fillWidth, height: battHeight - fillInset * 2)
    let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: size * 0.02, yRadius: size * 0.02)
    NSColor(red: 1.0, green: 0.82, blue: 0.22, alpha: 1.0).setFill()
    fillPath.fill()
    
    // Leaf / Eco Badge
    let leafSymbol = "leaf.fill"
    if let leafImg = NSImage(systemSymbolName: leafSymbol, accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: size * 0.26, weight: .bold)
        if let configured = leafImg.withSymbolConfiguration(config) {
            let symbolSize = size * 0.28
            let symbolRect = CGRect(x: size * 0.50, y: size * 0.16, width: symbolSize, height: symbolSize)
            
            // Badge background circle
            let badgeRect = symbolRect.insetBy(dx: -size * 0.04, dy: -size * 0.04)
            NSColor(red: 0.07, green: 0.32, blue: 0.22, alpha: 0.95).setFill()
            NSBezierPath(ovalIn: badgeRect).fill()
            
            NSColor(red: 0.35, green: 0.95, blue: 0.6, alpha: 1.0).setFill()
            configured.draw(in: symbolRect)
        }
    }
    
    img.unlockFocus()
    return img
}

func savePNG(image: NSImage, path: String) {
    if let tiff = image.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: path))
    }
}

let fileManager = FileManager.default
let iconsetDir = "/tmp/AutoLowPower.iconset"
try? fileManager.removeItem(atPath: iconsetDir)
try? fileManager.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, sz) in sizes {
    let img = makeIcon(size: sz)
    savePNG(image: img, path: "\(iconsetDir)/\(name)")
}

print("Icon set generated in \(iconsetDir)")
