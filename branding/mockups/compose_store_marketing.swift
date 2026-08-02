import AppKit

struct MockupSpec {
    let background: String
    let screen: String
    let output: String
    let title: String
    let subtitle: String
}

let canvasSize = NSSize(width: 1206, height: 2622)
let root = FileManager.default.currentDirectoryPath

let specs = [
    MockupSpec(
        background: "branding/mockups/backgrounds/overview-year-v1.png",
        screen: "screenshots/ui-audit-today-final.png",
        output: "branding/mockups/app-store/00-skygrid-overview-v1.png",
        title: ["YOUR SKY.", "YOUR YEAR."].joined(separator: String(UnicodeScalar(10))),
        subtitle: "A quiet daily record, made one morning at a time."
    ),
    MockupSpec(
        background: "branding/mockups/backgrounds/personal-ritual-v1.png",
        screen: "screenshots/ui-audit-onboarding-questions.png",
        output: "branding/mockups/app-store/04-your-morning-your-rhythm-v1.png",
        title: ["YOUR MORNING.", "YOUR RHYTHM."].joined(separator: String(UnicodeScalar(10))),
        subtitle: "Start with a ritual that fits the way you wake."
    ),
    MockupSpec(
        background: "branding/mockups/backgrounds/full-archive-v1.png",
        screen: "screenshots/ui-audit-paywall-final.png",
        output: "branding/mockups/app-store/05-keep-the-whole-story-v1.png",
        title: ["KEEP THE", "WHOLE STORY."].joined(separator: String(UnicodeScalar(10))),
        subtitle: "Your newest 30 days stay free. Keep every sky when you’re ready."
    )
]

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        red: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: 1
    )
}

func drawAspectFill(_ image: NSImage, in rect: NSRect) {
    let scale = max(rect.width / image.size.width, rect.height / image.size.height)
    let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    let target = NSRect(
        x: rect.midX - size.width / 2,
        y: rect.midY - size.height / 2,
        width: size.width,
        height: size.height
    )
    image.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
}

func textAttributes(font: NSFont, color: NSColor, alignment: NSTextAlignment, kern: CGFloat = 0, lineSpacing: CGFloat = 0) -> [NSAttributedString.Key: Any] {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineSpacing = lineSpacing
    paragraph.lineBreakMode = .byWordWrapping
    return [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
        .kern: kern
    ]
}

func draw(_ string: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
    NSAttributedString(string: string, attributes: attributes).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

for spec in specs {
    guard let background = NSImage(contentsOfFile: root + "/" + spec.background),
          let screen = NSImage(contentsOfFile: root + "/" + spec.screen) else { continue }

    let image = NSImage(size: canvasSize)
    image.lockFocus()
    drawAspectFill(background, in: NSRect(origin: .zero, size: canvasSize))
    let label = textAttributes(font: .systemFont(ofSize: 18, weight: .medium), color: color(0x77746E), alignment: .center, kern: 5)
    draw("SKY GRID", in: NSRect(x: 80, y: 2456, width: 1046, height: 32), attributes: label)
    let title = textAttributes(font: .systemFont(ofSize: 68, weight: .bold), color: color(0x1D1D1B), alignment: .center, lineSpacing: -2)
    draw(spec.title, in: NSRect(x: 58, y: 2244, width: 1090, height: 190), attributes: title)
    let subtitle = textAttributes(font: .systemFont(ofSize: 28, weight: .regular), color: color(0x706E69), alignment: .center, lineSpacing: 1)
    draw(spec.subtitle, in: NSRect(x: 95, y: 2168, width: 1016, height: 66), attributes: subtitle)
    let screenWidth: CGFloat = 972
    let inset: CGFloat = 9
    let screenHeight = screenWidth * screen.size.height / screen.size.width
    let card = NSRect(x: (canvasSize.width - screenWidth) / 2, y: 38, width: screenWidth, height: screenHeight)
    let border = NSBezierPath(roundedRect: card, xRadius: 42, yRadius: 42)
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000).withAlphaComponent(0.16)
    shadow.shadowBlurRadius = 26
    shadow.shadowOffset = NSSize(width: 0, height: -4)
    shadow.set()
    color(0xFFFFFF).setFill()
    border.fill()
    NSGraphicsContext.current?.restoreGraphicsState()
    let content = card.insetBy(dx: inset, dy: inset)
    NSBezierPath(roundedRect: content, xRadius: 34, yRadius: 34).addClip()
    screen.draw(in: content, from: .zero, operation: .sourceOver, fraction: 1)
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SkyGridBranding", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to encode a mockup PNG."])
    }
    try png.write(to: URL(fileURLWithPath: root + "/" + spec.output))
}
