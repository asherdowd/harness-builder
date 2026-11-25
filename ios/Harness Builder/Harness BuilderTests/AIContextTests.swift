//
//  AIContextTests.swift
//  Harness BuilderTests
//
//  What the assistant is told: a tool schema that matches the app's own
//  lists, and a description of the open harness that is accurate, compact and
//  limited to what the user agreed to share.
//

import Foundation
import Testing
@testable import Harness_Builder

@MainActor
struct AIContextTests {
    private func state() -> AppState {
        var a = Fixture.connector("A", name: "Injector plug", shape: "square-4pin",
                                  pins: [Fixture.pin(1, color: "GRN/WHT", guess: "Injector 1", netId: "W-1", netType: "wire", role: "signal", gauge: 20),
                                         Fixture.pin(2, color: nil, guess: nil, populated: false),
                                         Fixture.pin(3, color: nil, guess: nil)])
        a.displayName = "Injector plug"
        let b = Fixture.connector("B", name: "ECU plug A", pins: [Fixture.pin(1, color: "GRN/WHT", guess: "Injector 1", netId: "W-1", netType: "wire")])
        let secret = Fixture.connector("S", name: "Hidden plug", pins: [Fixture.pin(1, color: "VIOLET-SECRET", guess: "secret function")])
        return AppState(harnesses: [Fixture.harness("H1", title: "Engine", plugs: [a, b]),
                                    Fixture.harness("H2", title: "Firewall", plugs: [secret])], activeID: "H1")
    }

    // MARK: the tool

    private func tool() -> [String: Any] { AIContext.tool }
    private func changeProps() throws -> [String: Any] {
        let schema = try #require(tool()["input_schema"] as? [String: Any])
        let props = try #require(schema["properties"] as? [String: Any])
        let changes = try #require(props["changes"] as? [String: Any])
        let items = try #require(changes["items"] as? [String: Any])
        return try #require(items["properties"] as? [String: Any])
    }

    @Test func theToolIsStrictAndNamed() {
        #expect(tool()["name"] as? String == "propose_changes")
        #expect(tool()["strict"] as? Bool == true)
        let schema = tool()["input_schema"] as? [String: Any]
        #expect(schema?["additionalProperties"] as? Bool == false)
        #expect((schema?["required"] as? [String])?.sorted() == ["changes", "summary"])
    }

    @Test func theSchemaListsExactlyTheAppsOwnShapesRolesAndGauges() throws {
        let props = try changeProps()
        let shapes = (props["shape"] as? [String: Any])?["enum"] as? [String]
        let roles = (props["role"] as? [String: Any])?["enum"] as? [String]
        let gauges = (props["gauge"] as? [String: Any])?["enum"] as? [Int]
        let kinds = (props["type"] as? [String: Any])?["enum"] as? [String]
        #expect(shapes == ShapeCatalog.all.map(\.key))
        #expect(roles == ["power", "signal", "ground"])
        #expect(gauges == gaugeChoices)
        #expect(kinds == ["add_plug", "set_pin", "connect"])
    }

    @Test func theSchemaOffersNoWayToDelete() throws {
        let props = try changeProps()
        let kinds = (props["type"] as? [String: Any])?["enum"] as? [String] ?? []
        #expect(!kinds.contains { $0.contains("delete") || $0.contains("remove") || $0.contains("clear") })
        #expect(props.keys.allSatisfy { !$0.contains("delete") && !$0.contains("remove") })
    }

    @Test func everyFieldTheDecoderReadsIsInTheSchema() throws {
        let props = Set(try changeProps().keys)
        let readByDecoder: Set<String> = ["type", "ref", "shape", "name", "rows", "cols", "plug", "pin", "color", "function", "role", "gauge",
                                          "plug_a", "pin_a", "plug_b", "pin_b"]
        #expect(props == readByDecoder)
    }

    @Test func theToolCanBeSerializedToJSON() throws {
        let data = try JSONSerialization.data(withJSONObject: tool(), options: [.sortedKeys])
        #expect(data.count > 500)
    }

    // MARK: the prompt

    @Test func thePromptDescribesTheOpenHarnessAccurately() {
        let p = AIContext.systemPrompt(state: state(), harnessID: "H1")
        #expect(p.contains("\"Engine\" (2 plugs)"))
        #expect(p.contains("Plug A \"Injector plug\", shape square-4pin, 3 pins, spare pins: 2"))
        #expect(p.contains("pin 1: color GRN/WHT; does: Injector 1; role signal; 20 AWG; wire W-1"))
        #expect(p.contains("W-1: A pin 1 + B pin 1"))
        #expect(p.contains("Pins not listed under a plug are wired with nothing set yet."))
    }

    @Test func thePromptStatesTheRulesAndTheAllowedValues() {
        let p = AIContext.systemPrompt(state: state(), harnessID: "H1")
        #expect(p.contains("cannot delete or clear anything"))
        #expect(p.contains("BLK, WHT, RED"))
        #expect(p.contains("22, 20, 18"))
        for shape in ShapeCatalog.all { #expect(p.contains(shape.key)) }
    }

    @Test func otherHarnessesAreListedByNameOnly() {
        let p = AIContext.systemPrompt(state: state(), harnessID: "H1")
        #expect(p.contains("S \"Hidden plug\" on \"Firewall\", 1 pins"))
        #expect(!p.contains("VIOLET-SECRET"))
        #expect(!p.contains("secret function"))
    }

    @Test func aMissingHarnessIsSaidPlainly() {
        #expect(AIContext.snapshot(state: state(), harnessID: "NOPE") == "There is no open harness.")
    }

    @Test func aHugeHarnessIsCutOffAndSaysSo() {
        let plugs = (1...60).map { Fixture.connector("P\($0)", name: "Plug number \($0)", pins: (1...60).map { n in
            Fixture.pin(n, color: "GRN/WHT", guess: "A fairly long description of what this wire does \(n)", role: "signal", gauge: 18) }) }
        let s = AppState(harnesses: [Fixture.harness("H1", plugs: plugs)], activeID: "H1")
        let text = AIContext.snapshot(state: s, harnessID: "H1")
        #expect(text.count < AIContext.maxHarnessCharacters + 5_000)
        #expect(text.contains("more plugs are not shown"))
    }

    @Test func theKeyAndBackupsAreNotInThePrompt() {
        let p = AIContext.systemPrompt(state: state(), harnessID: "H1")
        #expect(!p.contains("sk-ant"))
        #expect(!p.contains("state.json"))
    }
}
