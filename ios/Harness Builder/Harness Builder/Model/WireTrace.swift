//
//  WireTrace.swift
//  Harness Builder
//
//  Finds where a wire continues: other pins on the same net (same netId),
//  or, when a pin has no net, plugs listed as the same circuit.
//  Ported from the web mock's linksFor.
//

import Foundation

struct TraceLink: Identifiable, Hashable {
    var id: String { "\(plugID)#\(pinNumber ?? 0)" }
    var harnessID: String
    var harnessTitle: String
    var plugID: String
    var plugTitle: String
    var pinNumber: Int?     // nil for whole-plug matches
    var color: String?
    var same: Bool          // same net and same harness group: "same wire"
    var precise: Bool       // true when matched by net, false when matched by plug only
}

enum WireTrace {
    static func links(for fp: FlatPin, in connector: Connector, harnesses: [Harness]) -> [TraceLink] {
        var out: [TraceLink] = []

        if let net = fp.pin.netId, !net.isEmpty {
            for h in harnesses {
                for c in h.connectors {
                    for e in c.flatPins {
                        if c.id == connector.id && e.number == fp.number { continue }
                        guard e.pin.netId == net else { continue }
                        let same = fp.pin.netType != nil && e.pin.netType == fp.pin.netType
                        out.append(TraceLink(harnessID: h.id, harnessTitle: h.title,
                                             plugID: c.id, plugTitle: c.title,
                                             pinNumber: e.number, color: e.pin.color,
                                             same: same, precise: true))
                    }
                }
            }
            return out
        }

        for id in connector.sameCircuitAs ?? [] {
            for h in harnesses {
                if let c = h.connectors.first(where: { $0.id == id }) {
                    out.append(TraceLink(harnessID: h.id, harnessTitle: h.title,
                                         plugID: c.id, plugTitle: c.title,
                                         pinNumber: nil, color: nil, same: false, precise: false))
                }
            }
        }
        return out
    }

    /// Plugs on the open harness to outline: where the selected wire goes, or,
    /// with no wire selected, the plugs marked as the same circuit.
    static func highlightIDs(selected: Connector, pinIndex: Int?, harnesses: [Harness], activeID: String) -> Set<String> {
        if let idx = pinIndex, let fp = selected.flatPins.first(where: { $0.number == idx + 1 }) {
            let ids = links(for: fp, in: selected, harnesses: harnesses)
                .filter { $0.harnessID == activeID }
                .map(\.plugID)
            return Set(ids)
        }
        var set = Set(selected.sameCircuitAs ?? [])
        if let h = harnesses.first(where: { $0.id == activeID }) {
            for c in h.connectors where (c.sameCircuitAs ?? []).contains(selected.id) {
                set.insert(c.id)
            }
        }
        return set
    }
}
