//
//  WireColor.swift
//  Harness Builder
//
//  Turns a wire color code ("GRN/WHT", "LT BLU") into swatch colors and a
//  readable name. Ported from the web app's colorPalette. The hex values are
//  approximations of standard wire colors: check them against real wire.
//

import SwiftUI

enum WireColor {
    struct Segment {
        var token: String
        var isLight: Bool
        var hex: UInt32?      // nil = color code not recognized
        var outline: Bool     // needs a light edge to show on the dark background
    }

    private static let base: [String: UInt32] = [
        "BLK": 0x0d0d0d, "WHT": 0xf4f2ec, "RED": 0xc9372c, "BLU": 0x2f6fd6, "GRN": 0x3c9548,
        "YEL": 0xe8c332, "ORN": 0xe08a2e, "BRN": 0x6b4630, "PNK": 0xe493b3, "GRY": 0x8b9096,
    ]

    private static let names: [String: String] = [
        "BLK": "Black", "WHT": "White", "RED": "Red", "BLU": "Blue", "GRN": "Green",
        "YEL": "Yellow", "ORN": "Orange", "BRN": "Brown", "PNK": "Pink", "GRY": "Gray",
    ]

    private static func lighten(_ hex: UInt32, amount: Double = 0.35) -> UInt32 {
        func mix(_ c: UInt32) -> UInt32 { UInt32((Double(c) + (255 - Double(c)) * amount).rounded()) }
        let r = mix((hex >> 16) & 0xff), g = mix((hex >> 8) & 0xff), b = mix(hex & 0xff)
        return (r << 16) | (g << 8) | b
    }

    static func parse(_ code: String?) -> [Segment] {
        guard let code, !code.isEmpty, code.lowercased() != "n/a" else { return [] }
        return code.split(separator: "/").map { raw in
            var part = raw.trimmingCharacters(in: .whitespaces).uppercased()
            var light = false
            if part.hasPrefix("LT ") {
                light = true
                part = String(part.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
            let hex = base[part].map { light ? lighten($0) : $0 }
            return Segment(token: part, isLight: light, hex: hex, outline: part == "BLK" || part == "BRN")
        }
    }

    static func label(_ code: String?) -> String {
        let segs = parse(code)
        if segs.isEmpty { return "No color" }
        return segs.map { s in
            let name = names[s.token] ?? s.token
            return s.isLight ? "Light \(name)" : name
        }.joined(separator: " / ")
    }
}

/// Small one- or two-tone swatch for a wire color code.
struct ColorSwatch: View {
    let code: String?
    var width: CGFloat = 30
    var height: CGFloat = 16

    var body: some View {
        let segs = WireColor.parse(code)
        ZStack {
            if segs.isEmpty {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Palette.pinEmptyStroke, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(segs.enumerated()), id: \.offset) { item in
                        ZStack {
                            if let hex = item.element.hex {
                                Color(hex: hex)
                            } else {
                                Palette.chipFill
                                Text("?").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: 0xc99a4a))
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .stroke(segs.contains { $0.outline } ? Palette.bodyStroke : Palette.pinRing, lineWidth: 1))
            }
        }
        .frame(width: width, height: height)
    }
}
