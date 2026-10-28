import NagaCore
import SwiftUI

struct MouseVisualizerView: View {
    let profile: FfiNagaProfile
    var compact: Bool = false

    private var rgb: FfiRgbSettings { profile.rgb }

    private var intensity: Double {
        rgb.effect == "off" ? 0 : Double(rgb.brightness) / 100
    }

    private var sideButtons: [SideButtonLayout] {
        SideButtonLayout.layouts[profile.sidePlate] ?? SideButtonLayout.layouts["twelve"] ?? []
    }

    var body: some View {
        Canvas { context, size in
            let sx = size.width / 260
            let sy = size.height / 360
            context.scaleBy(x: sx, y: sy)

            drawShadow(context: &context)
            drawBody(context: &context)
            drawPalmHighlight(context: &context)
            drawPrimaryButtonSeam(context: &context)
            drawSidePanelRecess(context: &context)
            drawScroll(context: &context)
            drawLogo(context: &context)
            drawSideButtons(context: &context)
            drawContour(context: &context)
        }
        .frame(width: compact ? 180 : 260, height: compact ? 250 : 360)
        .accessibilityLabel("Razer Naga Trinity")
    }

    private func zoneColor(_ zone: ZoneKind) -> Color {
        let config: FfiZoneConfig
        switch zone {
        case .logo: config = rgb.zones.logo
        case .scroll: config = rgb.zones.scroll
        case .side: config = rgb.zones.side
        }
        if !config.enabled || rgb.effect == "off" {
            return Color(hex: 0x1A1B1D)
        }
        if rgb.syncZones {
            return Color(hexString: rgb.color) ?? Theme.accent
        }
        return Color(hexString: config.color) ?? Theme.accent
    }

    private func drawShadow(context: inout GraphicsContext) {
        let oval = Path(ellipseIn: CGRect(x: 52, y: 320, width: 156, height: 24))
        context.fill(oval, with: .color(Color.black.opacity(0.32)))
    }

    private func drawBody(context: inout GraphicsContext) {
        let path = bodyPath()

        context.fill(
            path,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(hex: 0x2C2D31), location: 0),
                    .init(color: Color(hex: 0x1A1B1E), location: 0.48),
                    .init(color: Color(hex: 0x101113), location: 1),
                ]),
                startPoint: CGPoint(x: 70, y: 12),
                endPoint: CGPoint(x: 200, y: 336)
            )
        )

        // Soft top-left specular — material, not glossy.
        context.fill(
            path,
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color.white.opacity(0.08), location: 0),
                    .init(color: Color.white.opacity(0.0), location: 0.72),
                ]),
                center: CGPoint(x: 120, y: 64),
                startRadius: 2,
                endRadius: 128
            )
        )

        // Quiet underside falloff near the palm.
        context.fill(
            path,
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color.black.opacity(0.0), location: 0.35),
                    .init(color: Color.black.opacity(0.18), location: 1),
                ]),
                center: CGPoint(x: 132, y: 250),
                startRadius: 20,
                endRadius: 150
            )
        )

        context.stroke(path, with: .color(Color.white.opacity(0.09)), lineWidth: 1.1)
    }

    private func bodyPath() -> Path {
        var path = Path()
        // Slightly tighter Naga-like silhouette: broader shoulders, tapered rear.
        path.move(to: CGPoint(x: 176, y: 16))
        path.addCurve(
            to: CGPoint(x: 238, y: 92),
            control1: CGPoint(x: 210, y: 18),
            control2: CGPoint(x: 236, y: 50)
        )
        path.addCurve(
            to: CGPoint(x: 242, y: 230),
            control1: CGPoint(x: 240, y: 132),
            control2: CGPoint(x: 244, y: 182)
        )
        path.addCurve(
            to: CGPoint(x: 152, y: 340),
            control1: CGPoint(x: 240, y: 292),
            control2: CGPoint(x: 200, y: 340)
        )
        path.addLine(to: CGPoint(x: 112, y: 340))
        path.addCurve(
            to: CGPoint(x: 30, y: 258),
            control1: CGPoint(x: 68, y: 340),
            control2: CGPoint(x: 34, y: 304)
        )
        path.addCurve(
            to: CGPoint(x: 22, y: 148),
            control1: CGPoint(x: 26, y: 226),
            control2: CGPoint(x: 20, y: 186)
        )
        path.addCurve(
            to: CGPoint(x: 86, y: 26),
            control1: CGPoint(x: 24, y: 96),
            control2: CGPoint(x: 46, y: 48)
        )
        path.addCurve(
            to: CGPoint(x: 176, y: 16),
            control1: CGPoint(x: 112, y: 10),
            control2: CGPoint(x: 146, y: 8)
        )
        path.closeSubpath()
        return path
    }

    private func drawPalmHighlight(context: inout GraphicsContext) {
        let oval = Path(ellipseIn: CGRect(x: 62, y: 40, width: 140, height: 34))
        context.fill(oval, with: .color(Color.white.opacity(0.04)))
    }

    private func drawPrimaryButtonSeam(context: inout GraphicsContext) {
        // Center seam between left / right primary buttons.
        var seam = Path()
        seam.move(to: CGPoint(x: 130, y: 34))
        seam.addCurve(
            to: CGPoint(x: 130, y: 112),
            control1: CGPoint(x: 130, y: 58),
            control2: CGPoint(x: 130, y: 90)
        )
        context.stroke(seam, with: .color(Color.black.opacity(0.38)), lineWidth: 1.1)
        context.stroke(seam, with: .color(Color.white.opacity(0.05)), lineWidth: 0.6)

        // Quiet button plate edge above the scroll well.
        var plate = Path()
        plate.move(to: CGPoint(x: 86, y: 108))
        plate.addCurve(
            to: CGPoint(x: 174, y: 108),
            control1: CGPoint(x: 108, y: 116),
            control2: CGPoint(x: 152, y: 116)
        )
        context.stroke(plate, with: .color(Color.black.opacity(0.22)), lineWidth: 1)
    }

    private func drawSidePanelRecess(context: inout GraphicsContext) {
        guard
            let minX = sideButtons.map(\.x).min(),
            let minY = sideButtons.map(\.y).min(),
            let maxX = sideButtons.map({ $0.x + $0.w }).max(),
            let maxY = sideButtons.map({ $0.y + $0.h }).max()
        else { return }

        let rect = CGRect(
            x: minX - 5,
            y: minY - 5,
            width: maxX - minX + 10,
            height: maxY - minY + 10
        )
        let recess = Path(roundedRect: rect, cornerRadius: 7)
        context.fill(recess, with: .color(Color.black.opacity(0.30)))
        context.stroke(recess, with: .color(Color.white.opacity(0.045)), lineWidth: 1)

        // Inner bevel so the pad reads as inset into the shell.
        let inset = Path(
            roundedRect: rect.insetBy(dx: 1.5, dy: 1.5),
            cornerRadius: 6
        )
        context.stroke(inset, with: .color(Color.black.opacity(0.35)), lineWidth: 0.8)
    }

    private func drawScroll(context: inout GraphicsContext) {
        let housing = Path(roundedRect: CGRect(x: 117, y: 116, width: 26, height: 50), cornerRadius: 11)
        context.fill(housing, with: .color(Color(hex: 0x08090A)))
        context.stroke(housing, with: .color(Color.white.opacity(0.07)), lineWidth: 1)

        let wheel = Path(roundedRect: CGRect(x: 120, y: 119, width: 20, height: 44), cornerRadius: 9)
        context.fill(wheel, with: .color(zoneColor(.scroll).opacity(intensity * 0.9)))

        // Wheel groove lines for geometry, not decoration noise.
        for offset in [8.0, 16.0, 24.0, 32.0] {
            let groove = Path(roundedRect: CGRect(x: 123, y: 119 + offset, width: 14, height: 1), cornerRadius: 0.5)
            context.fill(groove, with: .color(Color.black.opacity(0.22)))
        }

        let notch = Path(roundedRect: CGRect(x: 123, y: 138, width: 14, height: 2), cornerRadius: 1)
        context.fill(notch, with: .color(Color.white.opacity(0.14 * max(intensity, 0.2))))
    }

    private func drawLogo(context: inout GraphicsContext) {
        let center = CGPoint(x: 132, y: 250)
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - 26, y: center.y - 26, width: 52, height: 52)),
            with: .color(Color.black.opacity(0.42))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - 38, y: center.y - 38, width: 76, height: 76)),
            with: .color(zoneColor(.logo).opacity(intensity * 0.24))
        )

        var mark = Path()
        mark.move(to: CGPoint(x: center.x - 13, y: center.y))
        mark.addLine(to: CGPoint(x: center.x - 5, y: center.y))
        mark.addLine(to: CGPoint(x: center.x - 1, y: center.y + 13))
        mark.addLine(to: CGPoint(x: center.x + 2, y: center.y))
        mark.addLine(to: CGPoint(x: center.x + 9, y: center.y))
        mark.addLine(to: CGPoint(x: center.x + 4, y: center.y + 20))
        mark.addLine(to: CGPoint(x: center.x - 1, y: center.y + 13))
        mark.addLine(to: CGPoint(x: center.x - 7, y: center.y + 20))
        mark.closeSubpath()
        context.fill(mark, with: .color(zoneColor(.logo).opacity(max(intensity, 0.16))))
    }

    private func drawSideButtons(context: inout GraphicsContext) {
        let color = zoneColor(.side)
        for btn in sideButtons {
            let outerRect = CGRect(x: btn.x, y: btn.y, width: btn.w, height: btn.h)
            let outer = Path(roundedRect: outerRect, cornerRadius: 4.5)
            context.fill(outer, with: .color(Color(hex: 0x0C0D0F)))
            context.stroke(outer, with: .color(Color.white.opacity(0.08)), lineWidth: 0.7)

            let lit = Path(
                roundedRect: outerRect.insetBy(dx: 1.25, dy: 1.25),
                cornerRadius: 3.25
            )
            context.fill(lit, with: .color(color.opacity(intensity * 0.30)))

            // Top edge catch-light so keys read as raised overlays.
            let highlight = Path(
                roundedRect: CGRect(x: btn.x + 2, y: btn.y + 1.5, width: btn.w - 4, height: 1.2),
                cornerRadius: 0.6
            )
            context.fill(highlight, with: .color(Color.white.opacity(0.10)))

            let text = Text(btn.label)
                .font(.system(size: btn.w < 30 ? 8.5 : 10, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.68))
            context.draw(
                text,
                at: CGPoint(x: btn.x + btn.w / 2, y: btn.y + btn.h / 2),
                anchor: .center
            )
        }
    }

    private func drawContour(context: inout GraphicsContext) {
        var left = Path()
        left.move(to: CGPoint(x: 84, y: 56))
        left.addCurve(
            to: CGPoint(x: 54, y: 210),
            control1: CGPoint(x: 62, y: 84),
            control2: CGPoint(x: 50, y: 132)
        )
        context.stroke(left, with: .color(Color.white.opacity(0.05)), lineWidth: 1.5)

        var right = Path()
        right.move(to: CGPoint(x: 196, y: 68))
        right.addCurve(
            to: CGPoint(x: 218, y: 214),
            control1: CGPoint(x: 212, y: 108),
            control2: CGPoint(x: 222, y: 156)
        )
        context.stroke(right, with: .color(Color.black.opacity(0.28)), lineWidth: 1.3)
    }

    private enum ZoneKind { case logo, scroll, side }
}

private struct SideButtonLayout {
    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat
    let label: String

    static let layouts: [String: [SideButtonLayout]] = [
        "two": [
            .init(x: 22, y: 152, w: 50, h: 32, label: "1"),
            .init(x: 22, y: 190, w: 50, h: 32, label: "2"),
        ],
        "seven": [
            .init(x: 18, y: 130, w: 38, h: 26, label: "1"),
            .init(x: 60, y: 130, w: 38, h: 26, label: "2"),
            .init(x: 18, y: 160, w: 38, h: 26, label: "3"),
            .init(x: 60, y: 160, w: 38, h: 26, label: "4"),
            .init(x: 18, y: 190, w: 38, h: 26, label: "5"),
            .init(x: 60, y: 190, w: 38, h: 26, label: "6"),
            .init(x: 39, y: 220, w: 38, h: 26, label: "7"),
        ],
        "twelve": [
            .init(x: 14, y: 120, w: 28, h: 22, label: "1"),
            .init(x: 46, y: 120, w: 28, h: 22, label: "2"),
            .init(x: 78, y: 120, w: 28, h: 22, label: "3"),
            .init(x: 14, y: 146, w: 28, h: 22, label: "4"),
            .init(x: 46, y: 146, w: 28, h: 22, label: "5"),
            .init(x: 78, y: 146, w: 28, h: 22, label: "6"),
            .init(x: 14, y: 172, w: 28, h: 22, label: "7"),
            .init(x: 46, y: 172, w: 28, h: 22, label: "8"),
            .init(x: 78, y: 172, w: 28, h: 22, label: "9"),
            .init(x: 14, y: 198, w: 28, h: 22, label: "10"),
            .init(x: 46, y: 198, w: 28, h: 22, label: "11"),
            .init(x: 78, y: 198, w: 28, h: 22, label: "12"),
        ],
    ]
}
