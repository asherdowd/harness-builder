//
//  PlugArt.swift
//  Harness Builder
//
//  Draws one plug from an ArtModel. Everything is drawn relative to the
//  center of the model's width x height box.
//

import SwiftUI

/// How a pin looks for each confidence level (not color-coded on purpose).
private func confidenceStyle(_ confidence: String?) -> (opacity: Double, dashed: Bool) {
    switch confidence {
    case "High": return (1, false)
    case "Med-High": return (0.85, false)
    case "Med": return (0.7, false)
    case "Low-Med": return (0.55, true)
    case "Low": return (0.4, true)
    default: return (0.3, true)
    }
}

struct PinDotView: View {
    let pin: Pin

    var body: some View {
        if pin.populated {
            let style = confidenceStyle(pin.confidence)
            Circle()
                .fill(Palette.pinFill)
                .overlay(Circle().stroke(Palette.pinRing, style: StrokeStyle(lineWidth: 1.25, dash: style.dashed ? [1.5, 1.5] : [])))
                .opacity(style.opacity)
                .frame(width: 9, height: 9)
        } else {
            Circle()
                .stroke(Palette.pinEmptyStroke, style: StrokeStyle(lineWidth: 1.25, dash: [2, 2]))
                .frame(width: 9, height: 9)
        }
    }
}

struct PlugArt: View {
    @Environment(\.exportPrint) private var printStyle

    /// Plain white in the print-friendly export, to save ink.
    private var bodyFill: Color { printStyle ? .white : Palette.bodyFill }

    let model: ArtModel
    var showRoles: Bool = false

    var body: some View {
        let w = model.width
        let h = model.height
        ZStack {
            bodyLayer(w: w, h: h)
            ForEach(Array(model.pins.enumerated()), id: \.offset) { item in
                PinDotView(pin: item.element.pin)
                    .position(x: w / 2 + item.element.x, y: h / 2 + item.element.y)
                if showRoles, item.element.pin.populated, let role = WireRole(rawValue: item.element.pin.role ?? "") {
                    RoleBadge(role: role, size: 11)
                        .position(x: w / 2 + item.element.x + 7, y: h / 2 + item.element.y - 7)
                }
            }
        }
        .frame(width: w, height: h)
        .allowsHitTesting(false)
    }

    // MARK: helpers

    /// A path in plug-centered coordinates, moved into the view's own space.
    private func centered(_ p: Path, _ w: CGFloat, _ h: CGFloat) -> Path {
        p.offsetBy(dx: w / 2, dy: h / 2)
    }

    private func line(_ a: CGPoint, _ b: CGPoint) -> Path {
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        return p
    }

    private func layer(_ path: Path, fill: Color? = nil, stroke: Color? = nil,
                       lineWidth: CGFloat = 1.5, dash: [CGFloat] = [], opacity: Double = 1) -> some View {
        ZStack {
            if let fill {
                path.fill(fill)
            }
            if let stroke {
                path.stroke(stroke, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round, dash: dash))
            }
        }
        .opacity(opacity)
    }

    /// Small locking tab used on round housings.
    private func smallTab(centerX: CGFloat, topY: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(bodyFill)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Palette.bodyStroke, lineWidth: 1.25))
            .frame(width: 12, height: 7)
            .position(x: centerX, y: topY + 3.5)
    }

    // MARK: silhouettes

    @ViewBuilder
    private func bodyLayer(w: CGFloat, h: CGFloat) -> some View {
        switch model.kind {
        case .tapered(let t):
            taperedBody(t, w: w, h: h)

        case .round3Blade(let d):
            ZStack {
                Circle()
                    .fill(bodyFill)
                    .overlay(Circle().stroke(Palette.bodyStroke, lineWidth: 1.5))
                    .frame(width: d, height: d)
                    .position(x: w / 2, y: h / 2)
                smallTab(centerX: w / 2, topY: h / 2 - d / 2 - 6)
            }

        case .capsule(let cw, let ch):
            ZStack {
                RoundedRectangle(cornerRadius: cw / 2.4)
                    .fill(bodyFill)
                    .overlay(RoundedRectangle(cornerRadius: cw / 2.4).stroke(Palette.bodyStroke, lineWidth: 1.5))
                    .frame(width: cw, height: ch)
                    .position(x: w / 2, y: h / 2)
                smallTab(centerX: w / 2, topY: h / 2 - ch / 2 - 6)
            }

        case .bullet(let bw, let bh):
            ZStack {
                layer(centered(line(CGPoint(x: 0, y: -bh / 2 - 18), CGPoint(x: 0, y: -bh / 2)), w, h),
                      stroke: Palette.leadStroke, lineWidth: 2.5)
                RoundedRectangle(cornerRadius: bw / 2)
                    .fill(bodyFill)
                    .overlay(RoundedRectangle(cornerRadius: bw / 2).stroke(Palette.bodyStroke, lineWidth: 1.5))
                    .frame(width: bw, height: bh)
                    .position(x: w / 2, y: h / 2)
            }

        case .spade(let sw, let sh):
            ZStack {
                layer(centered(line(CGPoint(x: -sw / 2 - 20, y: 0), CGPoint(x: -sw / 2, y: 0)), w, h),
                      stroke: Palette.leadStroke, lineWidth: 2.5)
                layer(centered(spadePath(sw, sh), w, h), fill: bodyFill, stroke: Palette.bodyStroke)
            }

        case .lug(let r):
            ZStack {
                layer(centered(line(CGPoint(x: -r - 22, y: 0), CGPoint(x: -r - 2, y: 0)), w, h),
                      stroke: Palette.leadStroke, lineWidth: 3)
                Circle()
                    .stroke(Palette.bodyStroke, lineWidth: 4)
                    .frame(width: r * 2, height: r * 2)
                    .position(x: w / 2, y: h / 2)
                Circle()
                    .fill(Palette.bg)
                    .frame(width: (r - 6) * 2, height: (r - 6) * 2)
                    .position(x: w / 2, y: h / 2)
            }

        case .splice(let ends):
            ZStack {
                ForEach(Array(ends.enumerated()), id: \.offset) { item in
                    layer(centered(line(.zero, item.element), w, h), stroke: Palette.leadStroke, lineWidth: 2)
                }
                Circle()
                    .fill(bodyFill)
                    .overlay(Circle().stroke(Palette.bodyStroke, lineWidth: 1.5))
                    .frame(width: 18, height: 18)
                    .position(x: w / 2, y: h / 2)
            }

        case .torn:
            layer(centered(tornPath(), w, h), stroke: Palette.leadStroke, lineWidth: 2.5)

        case .provisional(let pw, let ph):
            RoundedRectangle(cornerRadius: 4)
                .stroke(Palette.bodyStroke, style: StrokeStyle(lineWidth: 1.25, dash: [4, 3]))
                .opacity(0.7)
                .frame(width: pw, height: ph)
                .position(x: w / 2, y: h / 2)

        case .unknown:
            Circle()
                .stroke(Color.red, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: 36, height: 36)
                .position(x: w / 2, y: h / 2)
        }
    }

    /// Tapered housing: narrower at the bottom, a raised locking tab on top, and a ridge line.
    @ViewBuilder
    private func taperedBody(_ t: TaperSpec, w: CGFloat, h: CGFloat) -> some View {
        let topW = t.bodyWidth
        let botW = t.bodyWidth * (1 - t.taper)
        let bh = t.bodyHeight
        let body = [
            CGPoint(x: -topW / 2, y: -bh / 2),
            CGPoint(x: topW / 2, y: -bh / 2),
            CGPoint(x: botW / 2, y: bh / 2),
            CGPoint(x: -botW / 2, y: bh / 2),
        ]
        let tabW = max(14, topW * t.tabRatio)
        let tab = [
            CGPoint(x: -tabW / 2, y: -bh / 2 - 8),
            CGPoint(x: tabW / 2, y: -bh / 2 - 8),
            CGPoint(x: tabW / 2 - 2, y: -bh / 2 + 2),
            CGPoint(x: -tabW / 2 + 2, y: -bh / 2 + 2),
        ]
        ZStack {
            layer(centered(roundedPolyPath(body, radius: t.corner), w, h), fill: bodyFill, stroke: Palette.bodyStroke, lineWidth: 1.5)
            layer(centered(roundedPolyPath(tab, radius: 2), w, h), fill: bodyFill, stroke: Palette.bodyStroke, lineWidth: 1.25)
            if t.ridge {
                layer(centered(line(CGPoint(x: -topW / 2 + 4, y: -bh / 2 + 7), CGPoint(x: topW / 2 - 4, y: -bh / 2 + 7)), w, h),
                      stroke: Palette.bodyStroke, lineWidth: 1, opacity: 0.55)
            }
        }
    }

    private func spadePath(_ w: CGFloat, _ h: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -w / 2, y: -h / 2))
        p.addLine(to: CGPoint(x: w / 2 - 6, y: -h / 2))
        p.addLine(to: CGPoint(x: w / 2, y: 0))
        p.addLine(to: CGPoint(x: w / 2 - 6, y: h / 2))
        p.addLine(to: CGPoint(x: -w / 2, y: h / 2))
        p.closeSubpath()
        return p
    }

    private func tornPath() -> Path {
        let pts = [CGPoint(x: 0, y: -22), CGPoint(x: -4, y: -14), CGPoint(x: 4, y: -8), CGPoint(x: -5, y: -2),
                   CGPoint(x: 3, y: 4), CGPoint(x: -3, y: 10), CGPoint(x: 0, y: 16)]
        var p = Path()
        p.move(to: pts[0])
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        return p
    }
}
