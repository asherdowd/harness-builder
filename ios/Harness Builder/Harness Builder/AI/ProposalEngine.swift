//
//  ProposalEngine.swift
//  Harness Builder
//
//  Checks an AI proposal against the app's own rules and works out exactly
//  what it would do, without changing anything. The result is a preview: the
//  new state, every value that would be replaced, every pin that would move
//  off a wire, and the problems from "Check this harness" that the proposal
//  would add. Nothing is applied until the user approves the preview.
//
//  Rules (version 1):
//  - No deletes. Existing values can be replaced, but each replacement is listed.
//  - Pins are only edited on the open harness; connections may reach other harnesses.
//  - Colors, roles, gauges and shapes must be ones the app already knows.
//  - A pin the AI fills in is marked "Guess" (low confidence).
//  - A connection needs two wired pins, and moves nothing silently.
//

import Foundation

struct FieldChange: Equatable, Identifiable {
    var plugID: String
    var plugTitle: String
    var pin: Int
    var field: String
    var before: String?
    var after: String

    var id: String { "\(plugID)#\(pin)#\(field)" }

    /// True when a value that was already there would be replaced.
    var isOverwrite: Bool { !(before ?? "").isEmpty && before != after }
}

/// A pin that would be taken off a wire other pins are on.
struct Rewire: Equatable {
    var plugTitle: String
    var pin: Int
    /// How many other pins stay on the old wire.
    var left: Int
}

struct ProposalPreview {
    var proposal: AIProposal
    /// The state the preview was made from. Applying is refused if this has changed.
    var base: AppState
    var errors: [String]
    var after: AppState?
    var newPlugs: [String]
    var fieldChanges: [FieldChange]
    var connections: [String]
    var rewires: [Rewire]
    /// Issues from Check this harness that the proposal would add.
    var newIssues: [MapIssue]

    var overwrites: [FieldChange] { fieldChanges.filter(\.isOverwrite) }
    var newProblems: [MapIssue] { newIssues.filter { $0.severity == .problem } }
    var hasEffect: Bool { !newPlugs.isEmpty || !fieldChanges.isEmpty || !connections.isEmpty }
    var canApply: Bool { errors.isEmpty && after != nil && hasEffect }

    /// True when applying needs more than one tap: something would be replaced
    /// or moved, or the proposal would add a problem.
    var needsConfirmation: Bool { !overwrites.isEmpty || !rewires.isEmpty || !newProblems.isEmpty }
}

enum ProposalEngine {
    static let maxChanges = 200
    static let maxNameLength = 40
    static let maxFunctionLength = 60

    static func preview(_ proposal: AIProposal, on state: AppState, harnessID: String) -> ProposalPreview {
        var run = Run(s: state, harnessID: harnessID)

        if !state.harnesses.contains(where: { $0.id == harnessID }) {
            run.errors.append("The open harness is no longer there.")
        } else if proposal.changes.isEmpty {
            run.errors.append("The assistant didn't propose any changes.")
        } else if proposal.changes.count > maxChanges {
            run.errors.append("That is too many changes at once (\(proposal.changes.count)). The limit is \(maxChanges).")
        } else {
            for (i, change) in proposal.changes.enumerated() { run.apply(change, index: i) }
        }

        var issues: [MapIssue] = []
        if run.errors.isEmpty {
            let before = Set(state.harnesses.flatMap { MapChecks.run(on: $0, in: state.harnesses) }.map(\.id))
            issues = run.s.harnesses
                .flatMap { MapChecks.run(on: $0, in: run.s.harnesses) }
                .filter { !before.contains($0.id) }
        }

        return ProposalPreview(proposal: proposal, base: state, errors: run.errors,
                               after: run.errors.isEmpty ? run.s : nil,
                               newPlugs: run.newPlugs, fieldChanges: run.fieldChanges,
                               connections: run.connections, rewires: run.rewires, newIssues: issues)
    }

    /// A color code the wizard could have produced: "GRN", "LT BLU", "GRN/WHT".
    static func normalizedColor(_ raw: String) -> String? {
        let parts = raw.split(separator: "/", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count) else { return nil }
        let p = ColorParts(code: raw)
        let known = Set(wireTokens.map(\.code))
        guard known.contains(p.main), p.stripe.isEmpty ? parts.count == 1 : known.contains(p.stripe) else { return nil }
        return p.code
    }

    // MARK: the working copy

    private struct Run {
        var s: AppState
        let harnessID: String
        var temps: [String: String] = [:]
        var errors: [String] = []
        var newPlugs: [String] = []
        var fieldChanges: [FieldChange] = []
        var connections: [String] = []
        var rewires: [Rewire] = []

        typealias Loc = (hi: Int, ci: Int, ri: Int, pi: Int)

        mutating func fail(_ index: Int, _ message: String) {
            errors.append("Change \(index + 1): \(message)")
        }

        func resolve(_ ref: String, openOnly: Bool) -> String? {
            if let real = temps[ref] { return real }
            for h in s.harnesses where !openOnly || h.id == harnessID {
                if h.connectors.contains(where: { $0.id == ref }) { return ref }
            }
            return nil
        }

        func title(of id: String) -> String {
            for h in s.harnesses {
                if let c = h.connectors.first(where: { $0.id == id }) { return c.title }
            }
            return id
        }

        func locate(plug id: String, pin number: Int) -> Loc? {
            for hi in s.harnesses.indices {
                guard let ci = s.harnesses[hi].connectors.firstIndex(where: { $0.id == id }) else { continue }
                var n = 0
                for ri in s.harnesses[hi].connectors[ci].rows.indices {
                    for pi in s.harnesses[hi].connectors[ci].rows[ri].pins.indices {
                        n += 1
                        if n == number { return (hi, ci, ri, pi) }
                    }
                }
                return nil
            }
            return nil
        }

        func pin(at l: Loc) -> Pin { s.harnesses[l.hi].connectors[l.ci].rows[l.ri].pins[l.pi] }

        mutating func setPin(_ p: Pin, at l: Loc) {
            s.harnesses[l.hi].connectors[l.ci].rows[l.ri].pins[l.pi] = p
        }

        /// Other pins (anywhere) on a wire, not counting the one given.
        func others(on net: String, excluding l: Loc) -> Int {
            var count = 0
            for hi in s.harnesses.indices {
                for ci in s.harnesses[hi].connectors.indices {
                    for ri in s.harnesses[hi].connectors[ci].rows.indices {
                        for pi in s.harnesses[hi].connectors[ci].rows[ri].pins.indices {
                            if (hi, ci, ri, pi) == (l.hi, l.ci, l.ri, l.pi) { continue }
                            if s.harnesses[hi].connectors[ci].rows[ri].pins[pi].netId == net { count += 1 }
                        }
                    }
                }
            }
            return count
        }

        // MARK: one change

        mutating func apply(_ change: AIChange, index i: Int) {
            switch change {
            case let .addPlug(ref, shape, name, rows, cols):
                addPlug(ref: ref, shape: shape, name: name, rows: rows, cols: cols, index: i)
            case let .setPin(plug, pin, color, function, role, gauge):
                setPin(plug: plug, pin: pin, color: color, function: function, role: role, gauge: gauge, index: i)
            case let .connect(plugA, pinA, plugB, pinB):
                connect(plugA, pinA, plugB, pinB, index: i)
            }
        }

        private mutating func addPlug(ref: String, shape: String, name: String, rows: Int?, cols: Int?, index i: Int) {
            guard let hi = s.harnesses.firstIndex(where: { $0.id == harnessID }) else { return }
            guard !ref.isEmpty, temps[ref] == nil, resolve(ref, openOnly: false) == nil else {
                return fail(i, "the plug reference \"\(ref)\" is empty or already used.")
            }
            guard let def = ShapeCatalog.def(shape) else {
                return fail(i, "\"\(shape)\" isn't a plug shape this app has.")
            }
            let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (1...ProposalEngine.maxNameLength).contains(clean.count) else {
                return fail(i, "a plug name must be 1 to \(ProposalEngine.maxNameLength) characters.")
            }

            var d = PlugDraft(newShape: shape)
            switch def.adjust {
            case .none:
                guard rows == nil, cols == nil else { return fail(i, "\(def.label) has a fixed size, so it can't be given rows or columns.") }
            case .grid:
                let r = rows ?? def.rows, c = cols ?? def.cols
                guard (1...ShapeLimits.maxRows).contains(r), (2...ShapeLimits.maxCols).contains(c), r * c <= ShapeLimits.maxPins else {
                    return fail(i, "\(r) rows of \(c) pins is outside what a plug can be (up to \(ShapeLimits.maxRows) rows, \(ShapeLimits.maxCols) columns and \(ShapeLimits.maxPins) pins).")
                }
                d.resize(rows: r, cols: c)
            case .cols:
                let c = cols ?? def.cols
                guard rows == nil, (2...ShapeLimits.maxInlineCols).contains(c) else {
                    return fail(i, "an inline plug has one row of 2 to \(ShapeLimits.maxInlineCols) pins.")
                }
                d.resize(cols: c)
            case .splice:
                let c = cols ?? def.cols
                guard rows == nil, (2...4).contains(c) else { return fail(i, "a splice has 2 to 4 wires.") }
                d.resize(cols: c)
            }
            d.name = clean

            var plug = d.connector()
            let allIDs = s.harnesses.flatMap { $0.connectors.map(\.id) }
            let id = "MY-" + String(format: "%02d", HarnessStore.nextNumber(prefix: "MY-", in: allIDs))
            plug.id = id
            plug.name = clean
            plug.custom = true
            let pins = plug.rows.flatMap(\.pins)
            plug.totalPositions = pins.count
            plug.populatedPositions = pins.filter(\.populated).count
            s.harnesses[hi].connectors.append(plug)
            temps[ref] = id
            newPlugs.append(clean)
        }

        private mutating func setPin(plug: String, pin number: Int, color: String?, function: String?,
                                     role: String?, gauge: Int?, index i: Int) {
            guard color != nil || function != nil || role != nil || gauge != nil else {
                return fail(i, "it doesn't set anything on pin \(number).")
            }
            guard let id = resolve(plug, openOnly: true) else {
                return fail(i, "plug \"\(plug)\" isn't on the open harness.")
            }
            guard let loc = locate(plug: id, pin: number) else {
                return fail(i, "\(title(of: id)) has no pin \(number).")
            }

            var p = pin(at: loc)
            let wasSpare = !p.populated
            var edits: [(String, String?, String)] = []

            if let color {
                guard let code = ProposalEngine.normalizedColor(color) else {
                    return fail(i, "\"\(color)\" isn't a wire color the app knows. Use codes like GRN, LT BLU or GRN/WHT.")
                }
                if code != p.color { edits.append(("Color", p.color, code)); p.color = code }
            }
            if let function {
                let f = function.trimmingCharacters(in: .whitespacesAndNewlines)
                guard (1...ProposalEngine.maxFunctionLength).contains(f.count), !f.contains("\n") else {
                    return fail(i, "a function must be one line of 1 to \(ProposalEngine.maxFunctionLength) characters.")
                }
                if f != p.guess { edits.append(("Function", p.guess, f)); p.guess = f }
            }
            if let role {
                guard WireRole(rawValue: role) != nil else {
                    return fail(i, "\"\(role)\" isn't a role. Use power, signal or ground.")
                }
                if role != p.role { edits.append(("Role", p.role, role)); p.role = role }
            }
            if let gauge {
                guard gaugeChoices.contains(gauge) else {
                    return fail(i, "\(gauge) isn't a gauge the app offers (\(gaugeChoices.map(String.init).joined(separator: ", "))).")
                }
                if gauge != p.gauge {
                    edits.append(("Gauge", p.gauge.map { "\($0) AWG" }, "\(gauge) AWG"))
                    p.gauge = gauge
                }
            }

            guard !edits.isEmpty else { return }
            let plugTitle = title(of: id)
            if wasSpare {
                p.populated = true
                fieldChanges.append(FieldChange(plugID: id, plugTitle: plugTitle, pin: number, field: "Pin", before: "spare", after: "wired"))
            }
            p.confidence = "Low"
            for e in edits {
                fieldChanges.append(FieldChange(plugID: id, plugTitle: plugTitle, pin: number, field: e.0, before: e.1, after: e.2))
            }
            setPin(p, at: loc)
        }

        private mutating func connect(_ plugA: String, _ pinA: Int, _ plugB: String, _ pinB: Int, index i: Int) {
            guard let idA = resolve(plugA, openOnly: false) else { return fail(i, "plug \"\(plugA)\" doesn't exist.") }
            guard let idB = resolve(plugB, openOnly: false) else { return fail(i, "plug \"\(plugB)\" doesn't exist.") }
            guard !(idA == idB && pinA == pinB) else { return fail(i, "a pin can't be connected to itself.") }
            guard let la = locate(plug: idA, pin: pinA) else { return fail(i, "\(title(of: idA)) has no pin \(pinA).") }
            guard let lb = locate(plug: idB, pin: pinB) else { return fail(i, "\(title(of: idB)) has no pin \(pinB).") }

            var a = pin(at: la), b = pin(at: lb)
            guard a.populated else { return fail(i, "\(title(of: idA)) pin \(pinA) is a spare. Set it up before connecting it.") }
            guard b.populated else { return fail(i, "\(title(of: idB)) pin \(pinB) is a spare. Set it up before connecting it.") }

            let netA = a.netId ?? "", netB = b.netId ?? ""
            guard netA.isEmpty || netB.isEmpty || netA != netB else { return }   // already one wire

            let net: String, type: String
            if !netA.isEmpty, !netB.isEmpty {
                // Two different wires: the pin with fewer pins left behind moves.
                let leftA = others(on: netA, excluding: la), leftB = others(on: netB, excluding: lb)
                if leftA <= leftB {
                    net = netB; type = b.netType ?? "wire"
                    if leftA > 0 { rewires.append(Rewire(plugTitle: title(of: idA), pin: pinA, left: leftA)) }
                } else {
                    net = netA; type = a.netType ?? "wire"
                    if leftB > 0 { rewires.append(Rewire(plugTitle: title(of: idB), pin: pinB, left: leftB)) }
                }
            } else if !netB.isEmpty {
                net = netB; type = b.netType ?? "wire"
            } else if !netA.isEmpty {
                net = netA; type = a.netType ?? "wire"
            } else {
                net = PlugDraft.newNet(); type = "wire"
            }

            a.netId = net; a.netType = type
            b.netId = net; b.netType = type
            setPin(a, at: la)
            setPin(b, at: lb)
            connections.append("\(title(of: idA)) · pin \(pinA) ↔ \(title(of: idB)) · pin \(pinB)")
        }
    }
}
