//
//  AIContext.swift
//  Harness Builder
//
//  What the assistant is told: the one tool it may use (with a strict schema),
//  the rules, the app's own lists of shapes, colors, roles and gauges, and the
//  open harness. Only the open harness is described in full. Plugs on other
//  harnesses are listed by name so a wire can be connected to them.
//

import Foundation

enum AIContext {
    static let toolName = "propose_changes"
    /// A harness this large is cut off rather than sent whole.
    static let maxHarnessCharacters = 40_000

    // MARK: the tool

    /// The tool definition, as sent to the API. `strict` makes the API hold
    /// the assistant to this schema. The app still checks every proposal itself.
    static var tool: [String: Any] {
        func str(_ d: String) -> [String: Any] { ["type": "string", "description": d] }
        func int(_ d: String) -> [String: Any] { ["type": "integer", "description": d] }
        var props: [String: Any] = [:]
        props["type"] = ["type": "string", "enum": ["add_plug", "set_pin", "connect"],
                         "description": "add_plug makes a new plug. set_pin fills in fields on one pin. connect joins two pins onto one wire."] as [String: Any]
        props["ref"] = str("add_plug: a short made-up name for the new plug, such as new1, so later changes can refer to it.")
        props["shape"] = ["type": "string", "enum": ShapeCatalog.all.map(\.key),
                          "description": "add_plug: the plug shape."] as [String: Any]
        props["name"] = str("add_plug: the plug's name, up to \(ProposalEngine.maxNameLength) characters.")
        props["rows"] = int("add_plug: rows, only for shapes that can change size.")
        props["cols"] = int("add_plug: pins per row, only for shapes that can change size.")
        props["plug"] = str("set_pin: the plug id, or the ref of a plug added earlier in this proposal.")
        props["pin"] = int("set_pin: the pin number, counting from 1.")
        props["color"] = str("set_pin: a wire color code such as GRN, LT BLU or GRN/WHT (main color, optional stripe).")
        props["function"] = str("set_pin: what the wire does, one short line.")
        props["role"] = ["type": "string", "enum": WireRole.allCases.map(\.rawValue),
                         "description": "set_pin: power, signal or ground."] as [String: Any]
        props["gauge"] = ["type": "integer", "enum": gaugeChoices, "description": "set_pin: wire gauge in AWG."] as [String: Any]
        props["plug_a"] = str("connect: the first plug id or ref.")
        props["pin_a"] = int("connect: the first pin number.")
        props["plug_b"] = str("connect: the second plug id or ref.")
        props["pin_b"] = int("connect: the second pin number.")

        var change: [String: Any] = [:]
        change["type"] = "object"
        change["additionalProperties"] = false
        change["required"] = ["type"]
        change["properties"] = props

        var top: [String: Any] = [:]
        top["summary"] = str("One plain sentence saying what the changes do.")
        top["changes"] = ["type": "array", "items": change,
                          "description": "The changes, in order. A plug must be added before its pins are set."] as [String: Any]

        var schema: [String: Any] = [:]
        schema["type"] = "object"
        schema["additionalProperties"] = false
        schema["required"] = ["summary", "changes"]
        schema["properties"] = top

        var tool: [String: Any] = [:]
        tool["name"] = toolName
        tool["description"] = "Propose changes to the open harness. The user reviews every change before anything is applied. Use this whenever the user describes plugs, pins, wires or connections to record."
        tool["strict"] = true
        tool["input_schema"] = schema
        return tool
    }

    // MARK: the prompt

    static func systemPrompt(state: AppState, harnessID: String) -> String {
        var out = """
        You help someone map the wiring harnesses in their car, using an app called Harness Builder. They talk to you in plain words while they build a harness.

        How you work:
        - You never change anything yourself. To record something, call the \(toolName) tool. The user reviews every change and decides.
        - Only record what the user told you or what clearly follows from it. If a color, pin number or plug is unclear, ask a short question instead of guessing. You may reply in plain text with or without a proposal.
        - You cannot delete or clear anything. If the user wants something removed, tell them to do it by hand in the plug editor.
        - Pins are numbered from 1 across the plug, row by row. Use plug ids exactly as listed below. Plugs added in the same proposal use a made-up ref you choose.
        - A pin must be set up before it can be connected. Connect pins only when the user says they join.
        - Keep replies short. The user is working in the garage.

        Allowed wire colors (main color, optional LT prefix, optional stripe after a slash): \(wireTokens.map(\.code).joined(separator: ", ")). Example: GRN/WHT, LT BLU.
        Roles: \(WireRole.allCases.map(\.rawValue).joined(separator: ", ")). Gauges (AWG): \(gaugeChoices.map(String.init).joined(separator: ", ")).

        Plug shapes you can add (key: label):
        """
        for d in ShapeCatalog.all {
            let size: String
            switch d.adjust {
            case .none: size = "\(d.count) pins, fixed size"
            case .grid: size = "rows 1-\(ShapeLimits.maxRows), pins per row 2-\(ShapeLimits.maxCols), at most \(ShapeLimits.maxPins) pins"
            case .cols: size = "one row, 2-\(ShapeLimits.maxInlineCols) pins (set cols)"
            case .splice: size = "2-4 wires (set cols)"
            }
            out += "\n- \(d.key): \(d.label), \(size)"
        }

        out += "\n\n" + snapshot(state: state, harnessID: harnessID)
        return out
    }

    /// The open harness in a compact form, plus the names of other plugs.
    static func snapshot(state: AppState, harnessID: String) -> String {
        guard let h = state.harnesses.first(where: { $0.id == harnessID }) else { return "There is no open harness." }
        var lines = ["The open harness is \"\(h.title)\" (\(h.connectors.count) plugs)."]
        var nets: [String: [String]] = [:]
        var used = lines[0].count
        var omitted = 0

        for c in h.connectors {
            var block = ["Plug \(c.id) \"\(c.title)\", shape \(c.shape), \(c.flatPins.count) pins"]
            let spare = c.flatPins.filter { !$0.pin.populated }.map { String($0.number) }
            if !spare.isEmpty { block[0] += ", spare pins: \(spare.joined(separator: ","))" }
            for fp in c.flatPins where fp.pin.populated {
                let p = fp.pin
                var parts: [String] = []
                if let v = p.color, !v.isEmpty { parts.append("color \(v)") }
                if let v = p.guess, !v.isEmpty { parts.append("does: \(v)") }
                if let v = p.role, !v.isEmpty { parts.append("role \(v)") }
                if let v = p.gauge { parts.append("\(v) AWG") }
                if let v = p.netId, !v.isEmpty {
                    parts.append("wire \(v)")
                    nets[v, default: []].append("\(c.id) pin \(fp.number)")
                }
                if !parts.isEmpty { block.append("  pin \(fp.number): " + parts.joined(separator: "; ")) }
            }
            let text = block.joined(separator: "\n")
            if used + text.count > maxHarnessCharacters {
                omitted += 1
                continue
            }
            used += text.count
            lines.append(text)
        }
        if omitted > 0 { lines.append("(\(omitted) more plugs are not shown because the harness is large.)") }

        let joined = nets.filter { $0.value.count > 1 }.sorted { $0.key < $1.key }
        if !joined.isEmpty {
            lines.append("Pins joined on one wire:")
            for (net, pins) in joined { lines.append("  \(net): \(pins.joined(separator: " + "))") }
        }
        lines.append("Pins not listed under a plug are wired with nothing set yet.")

        var others: [String] = []
        for other in state.harnesses where other.id != harnessID {
            for c in other.connectors {
                others.append("  \(c.id) \"\(c.title)\" on \"\(other.title)\", \(c.flatPins.count) pins")
            }
        }
        if !others.isEmpty {
            lines.append("Plugs on the user's other harnesses (a pin can be connected to these, but their pins can't be edited from here):")
            lines.append(contentsOf: others.prefix(80))
            if others.count > 80 { lines.append("  (and \(others.count - 80) more)") }
        }
        return lines.joined(separator: "\n")
    }
}
