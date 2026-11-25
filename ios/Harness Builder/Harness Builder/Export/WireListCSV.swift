//
//  WireListCSV.swift
//  Harness Builder
//
//  A wire list as CSV: one row for every wire, readable in Numbers, Excel
//  or Google Sheets.
//

import Foundation

enum WireListCSV {
    static let columns = ["Harness", "Plug", "Pin", "Color", "Function", "Gauge AWG", "Wire type", "Confidence", "Connects to"]

    /// `allHarnesses` is where "Connects to" looks for the other end of a wire,
    /// so a wire on one harness can name a plug on another.
    static func csv(_ harnesses: [Harness], allHarnesses: [Harness]? = nil) -> String {
        let all = allHarnesses ?? harnesses
        var lines = [columns.map { escape($0) }.joined(separator: ",")]
        for h in harnesses {
            for c in h.connectors {
                for fp in c.flatPins where fp.pin.populated {
                    let p = fp.pin
                    let fields = [
                        h.title,
                        c.title,
                        String(fp.number),
                        WireColor.label(p.color),
                        p.guess ?? "",
                        p.gauge.map(String.init) ?? "",
                        roleLabel(p.role),
                        p.confidence ?? "",
                        connections(of: p, onPlug: c.id, pin: fp.number, in: all).joined(separator: "; "),
                    ]
                    lines.append(fields.map { escape($0) }.joined(separator: ","))
                }
            }
        }
        // CRLF line endings are what spreadsheet apps expect.
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Wraps a field in quotes when it holds a comma, quote or line break.
    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func roleLabel(_ role: String?) -> String {
        switch role {
        case "power": return "Hot"
        case "signal": return "Signal"
        case "ground": return "Ground"
        default: return ""
        }
    }

    /// Other pins on the same net, as "Plug name · pin N".
    static func connections(of pin: Pin, onPlug plugID: String, pin number: Int, in harnesses: [Harness]) -> [String] {
        guard let net = pin.netId, !net.isEmpty else { return [] }
        var out: [String] = []
        for h in harnesses {
            for c in h.connectors {
                for e in c.flatPins where e.pin.netId == net && !(c.id == plugID && e.number == number) {
                    out.append("\(c.title) · pin \(e.number)")
                }
            }
        }
        return out
    }
}
