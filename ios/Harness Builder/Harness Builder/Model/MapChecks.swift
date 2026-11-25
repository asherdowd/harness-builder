//
//  MapChecks.swift
//  Harness Builder
//
//  "Check this harness": finds things that are probably mistakes in the map.
//  Problems are likely errors; notes are things worth a second look.
//

import Foundation

struct MapIssue: Identifiable, Equatable {
    enum Severity { case problem, note }

    var severity: Severity
    var title: String
    var detail: String
    var plugID: String
    var pinNumber: Int?

    var id: String { "\(plugID)#\(pinNumber ?? 0)#\(title)" }
}

enum MapChecks {
    /// Checks one harness. `all` is every harness, so a connection to a pin on
    /// another harness counts as connected.
    static func run(on harness: Harness, in all: [Harness]) -> [MapIssue] {
        var issues: [MapIssue] = []

        for c in harness.connectors {
            let wired = c.flatPins.filter { $0.pin.populated }

            if harness.kind == .component {
                if c.link == nil {
                    issues.append(MapIssue(severity: .note, title: "Not linked",
                                           detail: "\(c.title) isn't linked to a plug on another harness.",
                                           plugID: c.id, pinNumber: nil))
                }
            } else if wired.isEmpty {
                issues.append(MapIssue(severity: .note, title: "No wires set",
                                       detail: "\(c.title) has no wires on it yet.",
                                       plugID: c.id, pinNumber: nil))
            }

            // An empty pin that still holds wire data was probably emptied by hand and not cleaned up.
            for fp in c.flatPins where !fp.pin.populated {
                let p = fp.pin
                let leftover = !(p.color ?? "").isEmpty || !(p.guess ?? "").isEmpty || !(p.netId ?? "").isEmpty
                    || !(p.role ?? "").isEmpty || p.gauge != nil
                if leftover {
                    issues.append(MapIssue(severity: .note, title: "Spare pin has wire data",
                                           detail: "\(c.title) · pin \(fp.number) is marked empty but still has a color, function, role, gauge or connection on it.",
                                           plugID: c.id, pinNumber: fp.number))
                }
            }

            for fp in wired {
                let p = fp.pin
                if (p.color ?? "").isEmpty {
                    issues.append(MapIssue(severity: .note, title: "No color",
                                           detail: "\(c.title) · pin \(fp.number) has a wire with no color.",
                                           plugID: c.id, pinNumber: fp.number))
                }
                if (p.guess ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
                    issues.append(MapIssue(severity: .note, title: "Not labeled",
                                           detail: "\(c.title) · pin \(fp.number) doesn't say what the wire does.",
                                           plugID: c.id, pinNumber: fp.number))
                }
                // A connection you made that nothing else shares.
                if p.netType == "wire", let net = p.netId, !net.isEmpty,
                   WireListCSV.connections(of: p, onPlug: c.id, pin: fp.number, in: all).isEmpty {
                    issues.append(MapIssue(severity: .problem, title: "Connected to nothing",
                                           detail: "\(c.title) · pin \(fp.number) is marked as connected, but no other pin shares it.",
                                           plugID: c.id, pinNumber: fp.number))
                }
            }
        }

        // Pins joined on one net that disagree on color are worth a look.
        var byNet: [String: [(plug: Connector, fp: FlatPin)]] = [:]
        for c in harness.connectors {
            for fp in c.flatPins where fp.pin.populated {
                if let net = fp.pin.netId, !net.isEmpty { byNet[net, default: []].append((c, fp)) }
            }
        }
        for (net, list) in byNet {
            // Every pin on this wire, on this harness and on the others.
            var group = list.map(\.fp.pin)
            for h in all where h.id != harness.id {
                for c in h.connectors {
                    for fp in c.flatPins where fp.pin.netId == net && fp.pin.populated { group.append(fp.pin) }
                }
            }
            let colors = Set(group.compactMap(\.color).filter { !$0.isEmpty })
            let roles = Set(group.compactMap(\.role).filter { !$0.isEmpty })
            let gauges = Set(group.compactMap(\.gauge))
            let functions = Set(group.compactMap { $0.guess?.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty })

            if roles.contains("power"), roles.contains("ground"), let first = list.first {
                issues.append(MapIssue(severity: .problem, title: "Power and ground on one wire",
                                       detail: "One wire has pins marked power and pins marked ground. Check which is right.",
                                       plugID: first.plug.id, pinNumber: first.fp.number))
            }
            if gauges.count > 1, let first = list.first {
                issues.append(MapIssue(severity: .note, title: "Gauges differ along one wire",
                                       detail: "\(gauges.sorted().map { "\($0) AWG" }.joined(separator: ", ")) are on the same wire. That can be right if the wire changes at a splice.",
                                       plugID: first.plug.id, pinNumber: first.fp.number))
            }
            if functions.count > 1, let first = list.first {
                issues.append(MapIssue(severity: .note, title: "Functions differ along one wire",
                                       detail: "The pins on this wire are labeled differently. That can be right if each end names it its own way.",
                                       plugID: first.plug.id, pinNumber: first.fp.number))
            }
            if colors.count > 1, let first = list.first {
                issues.append(MapIssue(severity: .note, title: "Colors differ along one wire",
                                       detail: "\(colors.sorted().joined(separator: ", ")) are on the same wire. That can be right if the color changes at a splice or connector.",
                                       plugID: first.plug.id, pinNumber: first.fp.number))
            }
        }

        // Problems first, then notes, each in harness order.
        let order = Dictionary(uniqueKeysWithValues: harness.connectors.enumerated().map { ($1.id, $0) })
        return issues.sorted {
            if $0.severity != $1.severity { return $0.severity == .problem }
            return (order[$0.plugID] ?? 0, $0.pinNumber ?? 0, $0.title) < (order[$1.plugID] ?? 0, $1.pinNumber ?? 0, $1.title)
        }
    }
}
