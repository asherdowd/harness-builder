//
//  ArtModel.swift
//  Harness Builder
//
//  Works out what a plug looks like (size, pin positions, which silhouette).
//  Ported from the web app's shapeRenderers. The drawing itself is PlugArt.
//

import SwiftUI

struct TaperSpec {
    var bodyWidth: CGFloat
    var bodyHeight: CGFloat
    var taper: CGFloat
    var tabRatio: CGFloat
    var corner: CGFloat
    var ridge: Bool
}

enum ArtKind {
    case tapered(TaperSpec)
    case round3Blade(diameter: CGFloat)
    case capsule(width: CGFloat, height: CGFloat)
    case bullet(width: CGFloat, height: CGFloat)
    case spade(width: CGFloat, height: CGFloat)
    case lug(radius: CGFloat)
    case splice(ends: [CGPoint])
    case torn
    case provisional(width: CGFloat, height: CGFloat)
    case unknown
}

struct ArtModel {
    var width: CGFloat       // size the layout reserves for this plug
    var height: CGFloat
    var pins: [PinDot]       // relative to the plug's center
    var kind: ArtKind

    static func make(for c: Connector) -> ArtModel {
        let rows = normalizeRows(shape: c.shape, rows: c.rows)

        func tapered(colGap: CGFloat = 24, rowGap: CGFloat = 22, padX: CGFloat = 14, padY: CGFloat = 14, topExtra: CGFloat = 8,
                     extraW: CGFloat = 0, extraH: CGFloat = 0,
                     taper: CGFloat, tab: CGFloat, corner: CGFloat? = nil, ridge: Bool = true) -> ArtModel {
            let g = gridLayout(rows: rows, colGap: colGap, rowGap: rowGap, padX: padX, padY: padY, topExtra: topExtra)
            let spec = TaperSpec(bodyWidth: g.width, bodyHeight: g.height, taper: taper, tabRatio: tab,
                                 corner: corner ?? g.height / 2.6, ridge: ridge)
            return ArtModel(width: g.width + extraW, height: g.height + extraH, pins: g.pins, kind: .tapered(spec))
        }

        let firstPin = rows.first?.pins.first

        switch c.shape {
        case "rectangular-block":
            return tapered(extraW: 14, extraH: 16, taper: 0.12, tab: 0.32, corner: 4)
        case "inline-block":
            return tapered(colGap: 26, rowGap: 22, padX: 14, padY: 12, topExtra: 0, extraW: 10, extraH: 10,
                           taper: 0.1, tab: 0.3, corner: 3, ridge: false)
        case "square-4pin", "square-2pin":
            return tapered(colGap: 22, rowGap: 22, padX: 15, padY: 15, topExtra: 6, taper: 0.22, tab: 0.45, corner: 6)
        case "rounded-rectangle-3pin":
            return tapered(colGap: 22, rowGap: 20, padX: 16, padY: 13, topExtra: 0, taper: 0.14, tab: 0.36, ridge: false)

        case "round-3blade":
            guard let first = rows.first else { return unknownArt }
            let d: CGFloat = 58, spacing: CGFloat = 18
            let startX = -CGFloat(first.pins.count - 1) * spacing / 2
            let pins = first.pins.enumerated().map { PinDot(x: startX + CGFloat($0.offset) * spacing, y: 2, pin: $0.element) }
            return ArtModel(width: d, height: d, pins: pins, kind: .round3Blade(diameter: d))

        case "round-2pin-vertical":
            guard rows.count >= 2, let top = rows[0].pins.first, let bottom = rows[1].pins.first else { return unknownArt }
            let w: CGFloat = 34, h: CGFloat = 58
            return ArtModel(width: w, height: h,
                            pins: [PinDot(x: 0, y: -13, pin: top), PinDot(x: 0, y: 13, pin: bottom)],
                            kind: .capsule(width: w, height: h))

        case "single-bullet":
            guard let pin = firstPin else { return unknownArt }
            let w: CGFloat = 20, h: CGFloat = 40
            return ArtModel(width: w, height: h + 18, pins: [PinDot(x: 0, y: 0, pin: pin)], kind: .bullet(width: w, height: h))

        case "single-spade":
            guard let pin = firstPin else { return unknownArt }
            let w: CGFloat = 30, h: CGFloat = 16
            return ArtModel(width: w + 20, height: h, pins: [PinDot(x: -w / 2 + 8, y: 0, pin: pin)], kind: .spade(width: w, height: h))

        case "ground-lug":
            let r: CGFloat = 13
            return ArtModel(width: r * 2 + 22, height: r * 2 + 6, pins: [], kind: .lug(radius: r))

        case "soldered-splice":
            guard let first = rows.first else { return unknownArt }
            let angles: [Double] = [-55, -18, 18, 55]
            let len: CGFloat = 30
            var ends: [CGPoint] = []
            var pins: [PinDot] = []
            for (i, p) in first.pins.enumerated() where i < angles.count {
                let rad = angles[i] * .pi / 180
                let end = CGPoint(x: CGFloat(sin(rad)) * len, y: -CGFloat(cos(rad)) * len)
                ends.append(end)
                pins.append(PinDot(x: end.x, y: end.y, pin: p))
            }
            return ArtModel(width: 90, height: 60, pins: pins, kind: .splice(ends: ends))

        case "single-wire-torn":
            guard let pin = firstPin else { return unknownArt }
            return ArtModel(width: 26, height: 42, pins: [PinDot(x: 0, y: 16, pin: pin)], kind: .torn)

        default:
            // A shape that isn't hand-drawn yet but is flagged as pending: a neutral dashed block.
            if c.shapeProvisional == true, !rows.isEmpty {
                let g = gridLayout(rows: rows)
                return ArtModel(width: g.width + 10, height: g.height + 16, pins: g.pins,
                                kind: .provisional(width: g.width, height: g.height))
            }
            // No renderer and no note saying why: drawn loudly on purpose.
            return unknownArt
        }
    }

    private static var unknownArt: ArtModel {
        ArtModel(width: 40, height: 40, pins: [], kind: .unknown)
    }
}
