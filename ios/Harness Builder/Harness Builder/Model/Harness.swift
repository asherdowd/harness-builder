//
//  Harness.swift
//  Harness Builder
//
//  Data model. Field names match the harness JSON used by the web app, so the
//  same files decode here. Unknown keys in the JSON are ignored.
//

import Foundation

// MARK: - Pin

/// One wire slot in a plug.
struct Pin: Codable, Hashable {
    var position: Int
    var populated: Bool
    var color: String?          // e.g. "BRN/BLK", "LT BLU"
    var guess: String?          // what the wire does
    var confidence: String?     // "High", "Med-High", "Med", "Low-Med", "Low"
    var netId: String?          // same netId = same electrical net
    var netType: String?        // which harness group the pin belongs to
    var colorNote: String?
    var colorCrossRef: ColorCrossRef?
    var role: String?           // app-only: "power", "signal" or "ground" (set by hand)
    var gauge: Int?             // app-only: wire gauge in AWG (optional)

    init(position: Int,
         populated: Bool = true,
         color: String? = nil,
         guess: String? = nil,
         confidence: String? = "High",
         netId: String? = nil,
         netType: String? = nil,
         colorNote: String? = nil,
         colorCrossRef: ColorCrossRef? = nil,
         role: String? = nil,
         gauge: Int? = nil) {
        self.position = position
        self.populated = populated
        self.color = color
        self.guess = guess
        self.confidence = confidence
        self.netId = netId
        self.netType = netType
        self.colorNote = colorNote
        self.colorCrossRef = colorCrossRef
        self.role = role
        self.gauge = gauge
    }

    enum CodingKeys: String, CodingKey {
        case position, populated, color, guess, confidence, netId, netType, colorNote, colorCrossRef, role, gauge
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        position = try c.decode(Int.self, forKey: .position)
        populated = try c.decodeIfPresent(Bool.self, forKey: .populated) ?? true
        color = try c.decodeIfPresent(String.self, forKey: .color)
        guess = try c.decodeIfPresent(String.self, forKey: .guess)
        confidence = try c.decodeIfPresent(String.self, forKey: .confidence)
        netId = try c.decodeIfPresent(String.self, forKey: .netId)
        netType = try c.decodeIfPresent(String.self, forKey: .netType)
        colorNote = try c.decodeIfPresent(String.self, forKey: .colorNote)
        colorCrossRef = try c.decodeIfPresent(ColorCrossRef.self, forKey: .colorCrossRef)
        role = try c.decodeIfPresent(String.self, forKey: .role)
        gauge = try c.decodeIfPresent(Int.self, forKey: .gauge)
    }
}

/// Result of comparing a wire color against other wires with the same function.
struct ColorCrossRef: Codable, Hashable {
    var matchCount: Int?
    var isOrphan: Bool?
    var signal: String?
}

// MARK: - Row

struct Row: Codable, Hashable {
    var row: Int
    var positions: Int
    var pins: [Pin]
}

// MARK: - Connector (a "plug" in the UI)

/// A link from a plug to a plug on another harness (used by components).
struct PlugLink: Codable, Hashable {
    var hid: String   // harness id
    var cid: String   // connector id
}

struct Connector: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var displayName: String?
    var location: String?
    var shape: String
    var shapeNote: String?
    var housingColor: String?
    var totalPositions: Int?
    var populatedPositions: Int?
    var rows: [Row]
    var description: String?
    var anomalies: [String]?
    var status: String?
    var condition: String?
    var buildAction: String?
    var partNumber: String?
    var gender: String?
    var sameCircuitAs: [String]?
    var shapeProvisional: Bool?
    var membershipUncertain: Bool?
    var hasOpenIssue: Bool?

    // App-only fields (not in the web app's data files)
    var custom: Bool?           // built by the user in the app
    var noRef: Bool?            // hide the reference tag (component copies)
    var link: PlugLink?         // logical link to a plug on another harness

    /// The name shown in the app.
    var title: String { displayName ?? name }

    /// All pins in reading order, numbered from 1 across rows.
    var flatPins: [FlatPin] {
        var out: [FlatPin] = []
        var n = 0
        for (rowIndex, r) in rows.enumerated() {
            for p in r.pins {
                n += 1
                out.append(FlatPin(number: n, rowIndex: rowIndex, pin: p))
            }
        }
        return out
    }

    var pinCount: Int { totalPositions ?? flatPins.count }
}

/// A pin together with its overall number (1-based, reading order).
struct FlatPin: Hashable {
    var number: Int
    var rowIndex: Int
    var pin: Pin
}

// MARK: - Harness (one tab)

enum HarnessKind: String, Codable {
    case harness
    case component
}

struct Harness: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var tab: String?            // short label for the tab; nil = use title
    var kind: HarnessKind
    var connectors: [Connector]

    var tabLabel: String { tab ?? title }
}

// MARK: - Whole app state (what gets saved on the device)

struct AppState: Codable, Equatable {
    var harnesses: [Harness]
    var activeID: String

    /// First-open state: one empty harness.
    static func blank() -> AppState {
        AppState(harnesses: [Harness(id: "H1", title: "My harness", tab: nil, kind: .harness, connectors: [])],
                 activeID: "H1")
    }
}
