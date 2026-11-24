//
//  PlugDraft.swift
//  Harness Builder
//
//  The plug being built or edited in the wizard, and the list of shapes the
//  user can pick from.
//

import Foundation

struct ShapeDef {
    enum Adjust { case none, grid, cols, splice }

    let key: String
    let label: String
    let rows: Int
    let cols: Int
    let adjust: Adjust
    let count: Int      // pins, for shapes with a fixed count
}

enum ShapeCatalog {
    static let all: [ShapeDef] = [
        ShapeDef(key: "rectangular-block", label: "Large block", rows: 2, cols: 4, adjust: .grid, count: 0),
        ShapeDef(key: "inline-block", label: "Inline block", rows: 1, cols: 4, adjust: .cols, count: 0),
        ShapeDef(key: "square-4pin", label: "Square 4-pin", rows: 1, cols: 1, adjust: .none, count: 4),
        ShapeDef(key: "square-2pin", label: "Square 2-pin", rows: 1, cols: 1, adjust: .none, count: 2),
        ShapeDef(key: "rounded-rectangle-3pin", label: "Rounded 3-pin", rows: 1, cols: 1, adjust: .none, count: 3),
        ShapeDef(key: "round-3blade", label: "Round 3-pin", rows: 1, cols: 1, adjust: .none, count: 3),
        ShapeDef(key: "round-2pin-vertical", label: "Round 2-pin", rows: 1, cols: 1, adjust: .none, count: 2),
        ShapeDef(key: "single-bullet", label: "Bullet", rows: 1, cols: 1, adjust: .none, count: 1),
        ShapeDef(key: "single-spade", label: "Spade", rows: 1, cols: 1, adjust: .none, count: 1),
        ShapeDef(key: "soldered-splice", label: "Splice", rows: 1, cols: 3, adjust: .splice, count: 0),
        ShapeDef(key: "single-wire-torn", label: "Loose wire", rows: 1, cols: 1, adjust: .none, count: 1),
    ]

    static func def(_ key: String) -> ShapeDef? {
        all.first { $0.key == key }
    }
}

struct PlugDraft {
    var shape: String
    var rowCount: Int
    var colCount: Int
    var pins: [Pin]
    var name: String
    /// When editing, the plug's pin layout can't change, only what is on each pin.
    var fixedRows: [Row]?
    /// When editing, the original plug.
    var base: Connector?

    static func blankPin(_ position: Int) -> Pin {
        Pin(position: position, populated: true, color: nil, guess: nil, confidence: "High")
    }

    /// A new plug of the chosen shape.
    init(newShape key: String) {
        let d = ShapeCatalog.def(key)
        shape = key
        rowCount = d?.rows ?? 1
        colCount = d?.cols ?? 1
        name = ""
        fixedRows = nil
        base = nil
        pins = []
        pins = (0..<total).map { Self.blankPin($0 + 1) }
    }

    /// An existing plug (layout fixed).
    init(editing c: Connector) {
        shape = c.shape
        rowCount = c.rows.count
        colCount = c.rows.map(\.positions).max() ?? 1
        pins = c.flatPins.map(\.pin)
        name = c.title
        fixedRows = c.rows
        base = c
    }

    var def: ShapeDef? { ShapeCatalog.def(shape) }

    var total: Int {
        if fixedRows != nil { return pins.count }
        guard let d = def else { return pins.count }
        switch d.adjust {
        case .grid: return rowCount * colCount
        case .cols, .splice: return colCount
        case .none: return d.count
        }
    }

    /// Changes the size of a new plug, keeping the pins already set.
    mutating func resize(rows: Int? = nil, cols: Int? = nil) {
        guard fixedRows == nil else { return }
        if let rows { rowCount = rows }
        if let cols { colCount = cols }
        let n = total
        pins = (0..<n).map { i in i < pins.count ? pins[i] : Self.blankPin(i + 1) }
    }

    /// The pin rows as stored in the model.
    func buildRows() -> [Row] {
        if let fixed = fixedRows {
            var out: [Row] = []
            var k = 0
            for r in fixed {
                var rowPins: [Pin] = []
                for _ in r.pins {
                    if k < pins.count { rowPins.append(pins[k]) }
                    k += 1
                }
                out.append(Row(row: r.row, positions: r.positions, pins: rowPins))
            }
            return out
        }
        func numbered(_ slice: [Pin]) -> [Pin] {
            slice.enumerated().map { i, p in
                var q = p
                q.position = i + 1
                return q
            }
        }
        if def?.adjust == .grid {
            var out: [Row] = []
            for r in 0..<rowCount {
                let start = min(r * colCount, pins.count)
                let end = min((r + 1) * colCount, pins.count)
                out.append(Row(row: r + 1, positions: colCount, pins: numbered(Array(pins[start..<end]))))
            }
            return out
        }
        return [Row(row: 1, positions: pins.count, pins: numbered(pins))]
    }

    /// The plug as it would be saved (used for the live preview and for saving).
    func connector() -> Connector {
        var c = base ?? Connector(id: "draft", name: name, location: "Built on this device", shape: shape, rows: [],
                                  status: "Unconfirmed", condition: "Not noted",
                                  shapeProvisional: false, membershipUncertain: false, hasOpenIssue: false,
                                  custom: true)
        c.rows = buildRows()
        return c
    }

    /// Pins that have a wire with a color set.
    var coloredCount: Int {
        pins.filter { $0.populated && !($0.color ?? "").isEmpty }.count
    }
}

/// A wire color code split into the parts the wizard edits: "LT GRN/WHT".
struct ColorParts {
    var main = ""
    var light = false
    var stripe = ""

    init(code: String?) {
        let parts = (code ?? "").split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
        if let first = parts.first {
            if first.hasPrefix("LT ") {
                light = true
                main = String(first.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else {
                main = first
            }
        }
        if parts.count > 1 { stripe = parts[1] }
    }

    var code: String {
        if main.isEmpty { return "" }
        return (light ? "LT " : "") + main + (stripe.isEmpty ? "" : "/" + stripe)
    }
}

let wireTokens: [(code: String, name: String)] = [
    ("BLK", "Black"), ("WHT", "White"), ("RED", "Red"), ("BLU", "Blue"), ("GRN", "Green"),
    ("YEL", "Yellow"), ("ORN", "Orange"), ("BRN", "Brown"), ("PNK", "Pink"), ("GRY", "Gray"),
]

let gaugeChoices = [22, 20, 18, 16, 14, 12, 10, 8]
