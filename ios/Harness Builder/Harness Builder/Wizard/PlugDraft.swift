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

/// Largest plugs the wizard builds (modern ECU plugs go up to about 60 pins).
enum ShapeLimits {
    static let maxPins = 60
    static let maxRows = 6
    static let maxCols = 20
    static let maxInlineCols = 16
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

/// A connection chosen in the wizard that also has to be written onto the other
/// plug's pin when the draft is saved (so both ends share one net).
struct NetStamp: Codable, Equatable {
    var pinIndex: Int       // 0-based pin on the plug being built or edited
    var plugID: String      // the plug at the other end
    var pinNumber: Int      // 1-based pin on that plug
    var net: String
    var netType: String
}

struct PlugDraft: Codable, Equatable {
    var shape: String
    var rowCount: Int
    var colCount: Int
    var pins: [Pin]
    var name: String
    /// When editing, the plug's pin layout can't change, only what is on each pin.
    var fixedRows: [Row]?
    /// When editing, the original plug.
    var base: Connector?
    /// When editing, the pins as they were, to tell if any wired pins would be lost.
    var originalPins: [Pin] = []
    /// Connections to pins on other plugs, written onto those pins when saved.
    var stamps: [NetStamp] = []

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
        originalPins = pins
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

    /// Changes the size, keeping the pins already set (in order). The first
    /// change on an existing plug replaces its original layout with rows x pins.
    mutating func resize(rows: Int? = nil, cols: Int? = nil) {
        fixedRows = nil
        if let rows { rowCount = rows }
        if let cols { colCount = cols }
        let n = total
        pins = (0..<n).map { i in i < pins.count ? pins[i] : Self.blankPin(i + 1) }
    }

    /// Switches to another shape, keeping the pins already set (in order).
    mutating func changeShape(to key: String) {
        guard key != shape, let d = ShapeCatalog.def(key) else { return }
        let count = pins.count
        shape = key
        fixedRows = nil
        switch d.adjust {
        case .grid:
            var r = d.rows
            while (count + r - 1) / r > ShapeLimits.maxCols, r < ShapeLimits.maxRows { r += 1 }
            rowCount = r
            colCount = max(2, (count + r - 1) / r)
        case .cols:
            rowCount = 1
            colCount = min(max(count, 2), ShapeLimits.maxInlineCols)
        case .splice:
            rowCount = 1
            colCount = min(max(count, 2), 4)
        case .none:
            rowCount = 1
            colCount = 1
        }
        let n = total
        pins = (0..<n).map { i in i < pins.count ? pins[i] : Self.blankPin(i + 1) }
    }

    /// Pins that have a wire set on them in the original plug but are gone now.
    var droppedWiredCount: Int {
        guard originalPins.count > pins.count else { return 0 }
        return originalPins[pins.count...].filter { $0.populated && (!($0.color ?? "").isEmpty || !($0.guess ?? "").isEmpty) }.count
    }

    static func newNet() -> String {
        "W-" + String(UUID().uuidString.prefix(6))
    }

    /// Connects a pin to a pin on another plug: both end up on the same net.
    /// The other pin's net wins if it has one; otherwise this pin's own net is
    /// kept (so connecting to several pins builds one wire group); otherwise a new net.
    mutating func connect(pin index: Int, toPlug plugID: String, pinNumber: Int, targetPin: Pin) {
        guard pins.indices.contains(index) else { return }
        let theirs = targetPin.netId ?? ""
        let own = pins[index].netId ?? ""
        let net = !theirs.isEmpty ? theirs : (!own.isEmpty ? own : Self.newNet())
        let type = !theirs.isEmpty ? (targetPin.netType ?? "wire") : (pins[index].netType ?? "wire")
        pins[index].netId = net
        pins[index].netType = type
        stamps.removeAll { $0.pinIndex == index && $0.plugID == plugID && $0.pinNumber == pinNumber }
        stamps.append(NetStamp(pinIndex: index, plugID: plugID, pinNumber: pinNumber, net: net, netType: type))
    }

    /// When connecting this pin would take it off a wire that other pins are on
    /// (because the target pin is on a different wire), how many other pins stay
    /// on the old wire. Zero means the connection moves nothing worth warning about.
    func pinsLeftBehind(pin index: Int, movingTo target: Pin, in harnesses: [Harness]) -> Int {
        guard pins.indices.contains(index),
              let own = pins[index].netId, !own.isEmpty,
              let theirs = target.netId, !theirs.isEmpty, own != theirs else { return 0 }
        var count = pins.enumerated().filter { $0.offset != index && $0.element.netId == own }.count
        for h in harnesses {
            for c in h.connectors where c.id != base?.id {
                count += c.flatPins.filter { $0.pin.netId == own }.count
            }
        }
        return count
    }

    /// Takes a pin off its net (the pins it was connected to keep theirs).
    mutating func disconnect(pin index: Int) {
        guard pins.indices.contains(index) else { return }
        pins[index].netId = nil
        pins[index].netType = nil
        stamps.removeAll { $0.pinIndex == index }
    }

    /// The stamps that still match the pins (pins can be removed or changed after connecting).
    var validStamps: [NetStamp] {
        stamps.filter { pins.indices.contains($0.pinIndex) && pins[$0.pinIndex].netId == $0.net }
    }

    /// True once the user has changed anything (so leaving would lose it).
    var hasChanges: Bool {
        if let b = base {
            return pins != originalPins || shape != b.shape || name != b.title || fixedRows == nil
        }
        return !name.isEmpty || pins.contains { $0.color != nil || $0.guess != nil || $0.role != nil || $0.gauge != nil || $0.netId != nil || !$0.populated }
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
