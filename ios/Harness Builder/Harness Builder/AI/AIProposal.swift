//
//  AIProposal.swift
//  Harness Builder
//
//  What the assistant is allowed to ask for. The AI never edits anything: it
//  returns a list of these small, typed changes, and the app checks them,
//  previews them and applies them (see ProposalEngine). There is deliberately
//  no change that deletes or empties anything.
//
//  Plugs are named by id. A plug the proposal adds gets a made-up `ref` that
//  later changes in the same proposal can use; the app swaps in the real id.
//

import Foundation

struct AIProposal: Codable, Equatable {
    /// One plain sentence for the preview.
    var summary: String
    var changes: [AIChange]
}

enum AIChange: Equatable {
    /// A new plug on the open harness. `rows` and `cols` only apply to shapes
    /// that can change size; fixed shapes must leave them out.
    case addPlug(ref: String, shape: String, name: String, rows: Int?, cols: Int?)
    /// Fills in fields on one pin. Only the fields given are touched.
    case setPin(plug: String, pin: Int, color: String?, function: String?, role: String?, gauge: Int?)
    /// Joins two pins onto one wire.
    case connect(plugA: String, pinA: Int, plugB: String, pinB: Int)
}

extension AIChange: Codable {
    private enum Kind: String, Codable {
        case addPlug = "add_plug"
        case setPin = "set_pin"
        case connect
    }

    private enum Keys: String, CodingKey {
        case type, ref, shape, name, rows, cols, plug, pin, color, function, role, gauge
        case plugA = "plug_a", pinA = "pin_a", plugB = "plug_b", pinB = "pin_b"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .addPlug:
            self = .addPlug(ref: try c.decode(String.self, forKey: .ref),
                            shape: try c.decode(String.self, forKey: .shape),
                            name: try c.decode(String.self, forKey: .name),
                            rows: try c.decodeIfPresent(Int.self, forKey: .rows),
                            cols: try c.decodeIfPresent(Int.self, forKey: .cols))
        case .setPin:
            self = .setPin(plug: try c.decode(String.self, forKey: .plug),
                           pin: try c.decode(Int.self, forKey: .pin),
                           color: try c.decodeIfPresent(String.self, forKey: .color),
                           function: try c.decodeIfPresent(String.self, forKey: .function),
                           role: try c.decodeIfPresent(String.self, forKey: .role),
                           gauge: try c.decodeIfPresent(Int.self, forKey: .gauge))
        case .connect:
            self = .connect(plugA: try c.decode(String.self, forKey: .plugA),
                            pinA: try c.decode(Int.self, forKey: .pinA),
                            plugB: try c.decode(String.self, forKey: .plugB),
                            pinB: try c.decode(Int.self, forKey: .pinB))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case let .addPlug(ref, shape, name, rows, cols):
            try c.encode(Kind.addPlug, forKey: .type)
            try c.encode(ref, forKey: .ref)
            try c.encode(shape, forKey: .shape)
            try c.encode(name, forKey: .name)
            try c.encodeIfPresent(rows, forKey: .rows)
            try c.encodeIfPresent(cols, forKey: .cols)
        case let .setPin(plug, pin, color, function, role, gauge):
            try c.encode(Kind.setPin, forKey: .type)
            try c.encode(plug, forKey: .plug)
            try c.encode(pin, forKey: .pin)
            try c.encodeIfPresent(color, forKey: .color)
            try c.encodeIfPresent(function, forKey: .function)
            try c.encodeIfPresent(role, forKey: .role)
            try c.encodeIfPresent(gauge, forKey: .gauge)
        case let .connect(plugA, pinA, plugB, pinB):
            try c.encode(Kind.connect, forKey: .type)
            try c.encode(plugA, forKey: .plugA)
            try c.encode(pinA, forKey: .pinA)
            try c.encode(plugB, forKey: .plugB)
            try c.encode(pinB, forKey: .pinB)
        }
    }
}
