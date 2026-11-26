//
//  HarnessSVG.swift
//  Harness Builder
//
//  Writes a harness drawing as an SVG: plain vector shapes and text that open
//  in Illustrator, Inkscape, Figma and browsers. It draws the same layout as
//  the app (trunk, leads, plugs, pins, role symbols, plug names) using the
//  same palette, resolved to colors for the chosen export style.
//
//  Keep this in step with PlugArt: the plug silhouettes are drawn twice
//  (once for the screen, once here).
//

import SwiftUI
import UIKit

@MainActor
enum HarnessSVG {
    /// The drawing for one harness, as SVG text.
    static func svg(for harness: Harness, style: ExportStyle = .dark) -> String {
        let layout = HarnessLayout(connectors: harness.connectors)
        let c = Colors(style: style)
        let w = layout.worldWidth, h = layout.worldHeight
        var o: [String] = []

        o.append(#"<?xml version="1.0" encoding="UTF-8"?>"#)
        o.append(#"<svg xmlns="http://www.w3.org/2000/svg" width="\#(n(w))" height="\#(n(h))" viewBox="0 0 \#(n(w)) \#(n(h))">"#)
        o.append("<title>\(esc(harness.title))</title>")
        o.append(#"<rect width="\#(n(w))" height="\#(n(h))" fill="\#(c.page)"/>"#)
        o.append(trunk(layout, c))
        o.append(leads(layout, c))
        for item in layout.items {
            o.append(plug(item, shiftX: layout.shiftX, c, style: style))
        }
        o.append("</svg>")
        return o.joined(separator: "\n") + "\n"
    }

    // MARK: colors

    /// Palette colors resolved to hex for one export style.
    struct Colors {
        let page: String
        let trunkFill, trunkStroke, trunkStrand, bodyFill, bodyStroke, leadStroke: String
        let pinFill, pinRing, pinEmpty, idText, nameText: String
        let bg: String

        init(style: ExportStyle) {
            func hex(_ color: Color) -> String {
                let ui = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style == .dark ? .dark : .light))
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                ui.getRed(&r, green: &g, blue: &b, alpha: &a)
                func byte(_ v: CGFloat) -> Int { Int((v * 255).rounded()) }
                return String(format: "#%02x%02x%02x", byte(r), byte(g), byte(b))
            }
            page = style == .print ? "#ffffff" : hex(Palette.bg)
            bg = page
            trunkFill = hex(Palette.trunkFill)
            trunkStroke = hex(Palette.trunkStroke)
            trunkStrand = hex(Palette.trunkStrand)
            bodyFill = style == .print ? "#ffffff" : hex(Palette.bodyFill)
            bodyStroke = hex(Palette.bodyStroke)
            leadStroke = hex(Palette.leadStroke)
            pinFill = hex(Palette.pinFill)
            pinRing = hex(Palette.pinRing)
            pinEmpty = hex(Palette.pinEmptyStroke)
            idText = hex(Palette.idText)
            nameText = hex(Palette.nameText)
        }

        func role(_ role: WireRole, style: ExportStyle) -> String {
            let ui = UIColor(role.color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style == .dark ? .dark : .light))
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
            return String(format: "#%02x%02x%02x", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
        }
    }

    // MARK: pieces

    private static func trunk(_ layout: HarnessLayout, _ c: Colors) -> String {
        let top: CGFloat = 30
        let cx = layout.shiftX
        if layout.items.isEmpty {
            return #"<rect x="\#(n(cx - 14))" y="\#(n(top))" width="28" height="190" rx="14" fill="none" stroke="\#(c.trunkStroke)" stroke-width="2" stroke-dasharray="6 6"/>"#
        }
        let bottom = layout.lastY
        var s = #"<rect x="\#(n(cx - 14))" y="\#(n(top))" width="28" height="\#(n(bottom - top))" rx="14" fill="\#(c.trunkFill)" stroke="\#(c.trunkStroke)" stroke-width="2"/>"#
        for dx in [-5, 0, 5] {
            let x = cx + CGFloat(dx)
            s += "\n" + #"<line x1="\#(n(x))" y1="\#(n(top + 6))" x2="\#(n(x))" y2="\#(n(bottom - 6))" stroke="\#(c.trunkStrand)" stroke-width="1" stroke-dasharray="1 5"/>"#
        }
        return s
    }

    private static func leads(_ layout: HarnessLayout, _ c: Colors) -> String {
        let sx = layout.shiftX
        var d = ""
        var dots = ""
        for it in layout.items {
            let edge = it.side * 14
            let plugEdge = it.x - it.side * ((it.width - 14) / 2)
            d += "M\(n(sx + edge)) \(n(it.y)) C\(n(sx + edge + it.side * 24)) \(n(it.y)) \(n(sx + plugEdge - it.side * 20)) \(n(it.y)) \(n(sx + plugEdge)) \(n(it.y)) "
            dots += "\n" + #"<circle cx="\#(n(sx + it.side * 14))" cy="\#(n(it.y))" r="2.5" fill="\#(c.trunkStroke)"/>"#
        }
        guard !d.isEmpty else { return "" }
        return #"<path d="\#(d.trimmingCharacters(in: .whitespaces))" fill="none" stroke="\#(c.leadStroke)" stroke-width="2"/>"# + dots
    }

    private static func plug(_ item: PlacedPlug, shiftX: CGFloat, _ c: Colors, style: ExportStyle) -> String {
        let cx = shiftX + item.x
        let w = item.width, h = item.height
        var o: [String] = []
        o.append(#"<g transform="translate(\#(n(cx)) \#(n(item.y)))" stroke-linecap="round" stroke-linejoin="round">"#)
        o.append(body(item.art.kind, w: w, h: h, c))
        for dot in item.art.pins {
            o.append(pin(dot, c))
        }
        for dot in item.art.pins {
            if dot.pin.populated, let role = WireRole(rawValue: dot.pin.role ?? "") {
                o.append(roleBadge(role, at: CGPoint(x: dot.x + 7, y: dot.y - 7), size: 11, c, style: style))
            }
        }
        o.append("</g>")
        o.append(text(item.connector.title, x: cx, centerY: item.y + h / 2 + 17, size: 14, bold: true, fill: c.idText))
        o.append(text(pinCountText(item.connector.pinCount), x: cx, centerY: item.y + h / 2 + 32, size: 11, bold: false, fill: c.nameText))
        return o.joined(separator: "\n")
    }

    private static func pin(_ dot: PinDot, _ c: Colors) -> String {
        if dot.pin.populated {
            let (opacity, dashed) = confidenceStyle(dot.pin.confidence)
            let dash = dashed ? #" stroke-dasharray="1.5 1.5""# : ""
            return #"<circle cx="\#(n(dot.x))" cy="\#(n(dot.y))" r="4.5" fill="\#(c.pinFill)" stroke="\#(c.pinRing)" stroke-width="1.25"\#(dash) opacity="\#(n(CGFloat(opacity)))"/>"#
        }
        return #"<circle cx="\#(n(dot.x))" cy="\#(n(dot.y))" r="4.5" fill="none" stroke="\#(c.pinEmpty)" stroke-width="1.25" stroke-dasharray="2 2"/>"#
    }

    private static func roleBadge(_ role: WireRole, at p: CGPoint, size: CGFloat, _ c: Colors, style: ExportStyle) -> String {
        let color = c.role(role, style: style)
        let inset = size * 0.12
        let rect = CGRect(x: p.x - size / 2 + inset, y: p.y - size / 2 + inset, width: size - inset * 2, height: size - inset * 2)
        let glyph = path(RoleGlyph(role: role).path(in: rect))
        return #"<circle cx="\#(n(p.x))" cy="\#(n(p.y))" r="\#(n(size / 2))" fill="\#(c.bg)" stroke="\#(color)" stroke-width="0.9"/>"#
            + "\n" + #"<path d="\#(glyph)" fill="none" stroke="\#(color)" stroke-width="\#(n(1.5 * size / 13))"/>"#
    }

    // MARK: silhouettes (plug-centered coordinates)

    private static func body(_ kind: ArtKind, w: CGFloat, h: CGFloat, _ c: Colors) -> String {
        func shape(_ d: String, fill: String? = nil, stroke: String? = nil, width: CGFloat = 1.5, dash: String? = nil, opacity: Double? = nil) -> String {
            var a = #"<path d="\#(d)""#
            a += fill.map { #" fill="\#($0)""# } ?? #" fill="none""#
            if let stroke { a += #" stroke="\#(stroke)" stroke-width="\#(n(width))""# }
            if let dash { a += #" stroke-dasharray="\#(dash)""# }
            if let opacity { a += #" opacity="\#(n(CGFloat(opacity)))""# }
            return a + "/>"
        }
        func line(_ a: CGPoint, _ b: CGPoint, width: CGFloat) -> String {
            shape("M\(n(a.x)) \(n(a.y)) L\(n(b.x)) \(n(b.y))", stroke: c.leadStroke, width: width)
        }
        func tab(y: CGFloat) -> String {
            #"<rect x="-6" y="\#(n(y))" width="12" height="7" rx="2" fill="\#(c.bodyFill)" stroke="\#(c.bodyStroke)" stroke-width="1.25"/>"#
        }

        switch kind {
        case .tapered(let t):
            let topW = t.bodyWidth, botW = t.bodyWidth * (1 - t.taper), bh = t.bodyHeight
            let body = [CGPoint(x: -topW / 2, y: -bh / 2), CGPoint(x: topW / 2, y: -bh / 2),
                        CGPoint(x: botW / 2, y: bh / 2), CGPoint(x: -botW / 2, y: bh / 2)]
            let tabW = max(14, topW * t.tabRatio)
            let tabPts = [CGPoint(x: -tabW / 2, y: -bh / 2 - 8), CGPoint(x: tabW / 2, y: -bh / 2 - 8),
                          CGPoint(x: tabW / 2 - 2, y: -bh / 2 + 2), CGPoint(x: -tabW / 2 + 2, y: -bh / 2 + 2)]
            var out = [shape(path(roundedPolyPath(body, radius: t.corner)), fill: c.bodyFill, stroke: c.bodyStroke),
                       shape(path(roundedPolyPath(tabPts, radius: 2)), fill: c.bodyFill, stroke: c.bodyStroke, width: 1.25)]
            if t.ridge {
                out.append(shape("M\(n(-topW / 2 + 4)) \(n(-bh / 2 + 7)) L\(n(topW / 2 - 4)) \(n(-bh / 2 + 7))",
                                 stroke: c.bodyStroke, width: 1, opacity: 0.55))
            }
            return out.joined(separator: "\n")

        case .round3Blade(let d):
            return #"<circle r="\#(n(d / 2))" fill="\#(c.bodyFill)" stroke="\#(c.bodyStroke)" stroke-width="1.5"/>"# + "\n" + tab(y: -d / 2 - 6)

        case .capsule(let cw, let ch):
            return #"<rect x="\#(n(-cw / 2))" y="\#(n(-ch / 2))" width="\#(n(cw))" height="\#(n(ch))" rx="\#(n(cw / 2.4))" fill="\#(c.bodyFill)" stroke="\#(c.bodyStroke)" stroke-width="1.5"/>"#
                + "\n" + tab(y: -ch / 2 - 6)

        case .bullet(let bw, let bh):
            return line(CGPoint(x: 0, y: -bh / 2 - 18), CGPoint(x: 0, y: -bh / 2), width: 2.5) + "\n"
                + #"<rect x="\#(n(-bw / 2))" y="\#(n(-bh / 2))" width="\#(n(bw))" height="\#(n(bh))" rx="\#(n(bw / 2))" fill="\#(c.bodyFill)" stroke="\#(c.bodyStroke)" stroke-width="1.5"/>"#

        case .spade(let sw, let sh):
            let d = "M\(n(-sw / 2)) \(n(-sh / 2)) L\(n(sw / 2 - 6)) \(n(-sh / 2)) L\(n(sw / 2)) 0 L\(n(sw / 2 - 6)) \(n(sh / 2)) L\(n(-sw / 2)) \(n(sh / 2)) Z"
            return line(CGPoint(x: -sw / 2 - 20, y: 0), CGPoint(x: -sw / 2, y: 0), width: 2.5) + "\n"
                + shape(d, fill: c.bodyFill, stroke: c.bodyStroke)

        case .lug(let r):
            return line(CGPoint(x: -r - 22, y: 0), CGPoint(x: -r - 2, y: 0), width: 3) + "\n"
                + #"<circle r="\#(n(r))" fill="none" stroke="\#(c.bodyStroke)" stroke-width="4"/>"# + "\n"
                + #"<circle r="\#(n(r - 6))" fill="\#(c.bg)"/>"#

        case .splice(let ends):
            var out = ends.map { line(.zero, $0, width: 2) }
            out.append(#"<circle r="9" fill="\#(c.bodyFill)" stroke="\#(c.bodyStroke)" stroke-width="1.5"/>"#)
            return out.joined(separator: "\n")

        case .torn:
            let pts = [CGPoint(x: 0, y: -22), CGPoint(x: -4, y: -14), CGPoint(x: 4, y: -8), CGPoint(x: -5, y: -2),
                       CGPoint(x: 3, y: 4), CGPoint(x: -3, y: 10), CGPoint(x: 0, y: 16)]
            let d = pts.enumerated().map { ($0.offset == 0 ? "M" : "L") + "\(n($0.element.x)) \(n($0.element.y))" }.joined(separator: " ")
            return shape(d, stroke: c.leadStroke, width: 2.5)

        case .provisional(let pw, let ph):
            return #"<rect x="\#(n(-pw / 2))" y="\#(n(-ph / 2))" width="\#(n(pw))" height="\#(n(ph))" rx="4" fill="none" stroke="\#(c.bodyStroke)" stroke-width="1.25" stroke-dasharray="4 3" opacity="0.7"/>"#

        case .unknown:
            return ##"<circle r="18" fill="none" stroke="#ff0000" stroke-width="1" stroke-dasharray="3 3"/>"##
        }
    }

    // MARK: text and numbers

    /// Text centered on `centerY`. SVG places text by its baseline, so move it down by about a third of the size.
    private static func text(_ s: String, x: CGFloat, centerY: CGFloat, size: CGFloat, bold: Bool, fill: String) -> String {
        let weight = bold ? " font-weight=\"700\"" : ""
        return #"<text x="\#(n(x))" y="\#(n(centerY + size * 0.35))" text-anchor="middle" font-family="-apple-system, Helvetica, Arial, sans-serif" font-size="\#(n(size))"\#(weight) fill="\#(fill)">\#(esc(s))</text>"#
    }

    /// A SwiftUI Path as SVG path data.
    static func path(_ p: Path) -> String {
        var parts: [String] = []
        p.forEach { e in
            switch e {
            case .move(let to): parts.append("M\(n(to.x)) \(n(to.y))")
            case .line(let to): parts.append("L\(n(to.x)) \(n(to.y))")
            case .quadCurve(let to, let c): parts.append("Q\(n(c.x)) \(n(c.y)) \(n(to.x)) \(n(to.y))")
            case .curve(let to, let c1, let c2): parts.append("C\(n(c1.x)) \(n(c1.y)) \(n(c2.x)) \(n(c2.y)) \(n(to.x)) \(n(to.y))")
            case .closeSubpath: parts.append("Z")
            }
        }
        return parts.joined(separator: " ")
    }

    /// Up to two decimals, no trailing zeros.
    static func n(_ v: CGFloat) -> String {
        var s = String(format: "%.2f", Double(v))
        while s.contains("."), s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s == "-0" ? "0" : s
    }

    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
