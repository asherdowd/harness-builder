//
//  StoreTests.swift
//  Harness BuilderTests
//
//  The store: harness and plug actions, links, and saving to the device.
//  Every test uses its own throwaway file.
//

import Foundation
import Testing
@testable import Harness_Builder

@MainActor
struct StoreTests {
    // MARK: first open

    @Test func startsWithOneEmptyHarness() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(at: url)
        #expect(store.isBlank)
        #expect(store.harnesses.count == 1)
        #expect(store.active.connectors.isEmpty)
        #expect(store.loadError == nil)
    }

    @Test func creatingAHarnessOnTheBlankStarterKeepsTheStarter() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(at: url)
        #expect(store.createHarness() == nil)
        #expect(store.harnesses.count == 1)
    }

    @Test func creatingAnotherHarnessGivesItAFreshIDAndOpensIt() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let state = AppState(harnesses: [Fixture.harness("H1"), Fixture.harness("H2")], activeID: "H1")
        let store = try Fixture.store(state, at: url)
        let id = try #require(store.createHarness())
        #expect(id == "H3")
        #expect(store.active.id == "H3")
        #expect(store.harnesses.count == 3)
    }

    // MARK: harness actions

    @Test func renamingTrimsAndIgnoresBlankNames() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(at: url)
        store.renameHarness(id: "H1", to: "  Engine bay  ")
        #expect(store.active.title == "Engine bay")
        #expect(store.active.tabLabel == "Engine bay")
        store.renameHarness(id: "H1", to: "   ")
        #expect(store.active.title == "Engine bay")
    }

    @Test func switchingToAnUnknownHarnessIsIgnored() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let state = AppState(harnesses: [Fixture.harness("H1"), Fixture.harness("H2")], activeID: "H1")
        let store = try Fixture.store(state, at: url)
        store.setActive("H2")
        #expect(store.active.id == "H2")
        store.setActive("nope")
        #expect(store.active.id == "H2")
    }

    @Test func deletingTheOpenHarnessOpensTheFirstOne() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let state = AppState(harnesses: [Fixture.harness("H1"), Fixture.harness("H2"), Fixture.harness("H3")], activeID: "H2")
        let store = try Fixture.store(state, at: url)
        store.deleteHarness(id: "H2")
        #expect(store.harnesses.map(\.id) == ["H1", "H3"])
        #expect(store.active.id == "H1")
    }

    @Test func deletingAClosedHarnessKeepsTheOpenOne() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let state = AppState(harnesses: [Fixture.harness("H1"), Fixture.harness("H2")], activeID: "H2")
        let store = try Fixture.store(state, at: url)
        store.deleteHarness(id: "H1")
        #expect(store.active.id == "H2")
    }

    @Test func deletingTheLastHarnessReturnsToTheBlankStart() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let state = AppState(harnesses: [Fixture.harness("H1", plugs: [Fixture.connector("P", pins: Fixture.pins(2))])], activeID: "H1")
        let store = try Fixture.store(state, at: url)
        store.deleteHarness(id: "H1")
        #expect(store.isBlank)
    }

    @Test func resetAllGoesBackToTheBlankStart() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let state = AppState(harnesses: [Fixture.harness("H1"), Fixture.harness("H2")], activeID: "H2")
        let store = try Fixture.store(state, at: url)
        store.resetAll()
        #expect(store.isBlank)
    }

    // MARK: plug actions

    @Test func addedPlugGetsAnIDADefaultNameAndCounts() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(at: url)
        let draft = Fixture.connector("x", name: "", pins: [Fixture.pin(1), Fixture.pin(2), Fixture.pin(3, color: nil, guess: nil, populated: false)])
        let id = try #require(store.addPlug(draft, toHarness: "H1"))
        #expect(id == "MY-01")
        let c = try #require(store.plug(id: id)).connector
        #expect(c.name == "Plug 1")
        #expect(c.custom == true)
        #expect(c.totalPositions == 3)
        #expect(c.populatedPositions == 2)
        #expect(!store.isBlank)
    }

    @Test func secondPlugGetsTheNextIDAndName() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(at: url)
        store.addPlug(Fixture.connector("x", name: "", pins: Fixture.pins(2)), toHarness: "H1")
        let id = try #require(store.addPlug(Fixture.connector("x", name: "", pins: Fixture.pins(2)), toHarness: "H1"))
        #expect(id == "MY-02")
        #expect(store.plug(id: id)?.connector.name == "Plug 2")
    }

    @Test func aNamedPlugKeepsItsName() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(at: url)
        let id = try #require(store.addPlug(Fixture.connector("x", name: "Horn", pins: Fixture.pins(2)), toHarness: "H1"))
        #expect(store.plug(id: id)?.connector.name == "Horn")
    }

    @Test func addingToAnUnknownHarnessDoesNothing() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(at: url)
        #expect(store.addPlug(Fixture.connector("x", pins: Fixture.pins(2)), toHarness: "nope") == nil)
        #expect(store.isBlank)
    }

    @Test func sixtyPinPlugIsStoredWhole() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(at: url)
        let id = try #require(store.addPlug(Fixture.connector("x", name: "ECU", pins: Fixture.pins(60), perRow: 10), toHarness: "H1"))
        let c = try #require(store.plug(id: id)).connector
        #expect(c.flatPins.count == 60)
        #expect(c.totalPositions == 60)
    }

    @Test func updatingAPlugRecountsItsPins() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(at: url)
        let id = try #require(store.addPlug(Fixture.connector("x", name: "A", pins: Fixture.pins(2)), toHarness: "H1"))
        store.updatePlug(id: id) { c in
            c.rows = [Row(row: 1, positions: 5, pins: Fixture.pins(5))]
        }
        let c = try #require(store.plug(id: id)).connector
        #expect(c.totalPositions == 5)
        #expect(c.populatedPositions == 5)
    }

    @Test func removingAPlugTakesItOffTheHarness() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let state = AppState(harnesses: [Fixture.harness("H1", plugs: [
            Fixture.connector("A", pins: Fixture.pins(1)), Fixture.connector("B", pins: Fixture.pins(1)),
        ])], activeID: "H1")
        let store = try Fixture.store(state, at: url)
        store.removePlug(id: "A")
        #expect(store.active.connectors.map(\.id) == ["B"])
        #expect(store.plug(id: "A") == nil)
    }

    @Test func movingPlugsReordersThemAndStopsAtTheEnds() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let ids = ["A", "B", "C"]
        let state = AppState(harnesses: [Fixture.harness("H1", plugs: ids.map { Fixture.connector($0, pins: Fixture.pins(1)) })], activeID: "H1")
        let store = try Fixture.store(state, at: url)
        store.movePlug(id: "B", by: -1)
        #expect(store.active.connectors.map(\.id) == ["B", "A", "C"])
        store.movePlug(id: "B", by: -1)         // already first
        #expect(store.active.connectors.map(\.id) == ["B", "A", "C"])
        store.movePlug(id: "C", by: 1)          // already last
        #expect(store.active.connectors.map(\.id) == ["B", "A", "C"])
        store.movePlug(id: "B", by: 1)
        #expect(store.active.connectors.map(\.id) == ["A", "B", "C"])
    }

    @Test func plugsAreFoundOnAnyHarness() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let state = AppState(harnesses: [
            Fixture.harness("H1", plugs: [Fixture.connector("A", pins: Fixture.pins(1))]),
            Fixture.harness("H2", plugs: [Fixture.connector("B", pins: Fixture.pins(1))]),
        ], activeID: "H1")
        let store = try Fixture.store(state, at: url)
        #expect(store.plug(id: "B")?.harness.id == "H2")
        #expect(store.plug(id: "zzz") == nil)
    }

    // MARK: links

    private func linkedStore(_ url: URL) throws -> HarnessStore {
        let state = AppState(harnesses: [
            Fixture.harness("C1", kind: .component, plugs: [Fixture.connector("CMP-01", pins: Fixture.pins(2))]),
            Fixture.harness("H2", plugs: [Fixture.connector("P1", pins: Fixture.pins(2)), Fixture.connector("P2", pins: Fixture.pins(2))]),
        ], activeID: "C1")
        return try Fixture.store(state, at: url)
    }

    @Test func linkingAPlugCanBeFollowedBothWays() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try linkedStore(url)
        store.setLink(from: "CMP-01", to: PlugLink(hid: "H2", cid: "P1"))
        let comp = try #require(store.plug(id: "CMP-01")).connector
        #expect(store.linkTarget(of: comp)?.id == "P1")
        #expect(store.linkedComponents(to: "P1").map(\.id) == ["CMP-01"])
        #expect(store.linkedComponents(to: "P2").isEmpty)
    }

    @Test func unlinkingClearsTheLink() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try linkedStore(url)
        store.setLink(from: "CMP-01", to: PlugLink(hid: "H2", cid: "P1"))
        store.setLink(from: "CMP-01", to: nil)
        let comp = try #require(store.plug(id: "CMP-01")).connector
        #expect(comp.link == nil)
        #expect(store.linkTarget(of: comp) == nil)
        #expect(store.linkedComponents(to: "P1").isEmpty)
    }

    @Test func linkPickerOffersOnlyPlugsOnOtherHarnesses() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try linkedStore(url)
        #expect(Set(store.linkCandidates(excludingHarness: "C1").map(\.id)) == ["P1", "P2"])
        #expect(store.linkCandidates(excludingHarness: "H2").map(\.id) == ["CMP-01"])
    }

    @Test func deletingALinkTargetLeavesNoCrashAndNoLink() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try linkedStore(url)
        store.setLink(from: "CMP-01", to: PlugLink(hid: "H2", cid: "P1"))
        store.removePlug(id: "P1")
        let comp = try #require(store.plug(id: "CMP-01")).connector
        #expect(store.linkTarget(of: comp) == nil)
    }

    // MARK: templates

    @Test func tryTheExampleLoadsThreeHarnesses() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(library: try Fixture.bundledLibrary(), at: url)
        store.loadExample()
        #expect(store.harnesses.map(\.id) == TemplateLibrary.exampleKeys)
        #expect(store.active.id == TemplateLibrary.exampleKeys[0])
        #expect(store.harnesses.allSatisfy { !$0.connectors.isEmpty })
        #expect(!store.isBlank)
    }

    @Test func aTemplateCanOnlyBeAddedOnceUnlessRepeatable() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(library: try Fixture.bundledLibrary(), at: url)
        let first = store.addTemplate(key: "VX")
        #expect(first == "VX")
        #expect(store.harnesses.map(\.id) == ["VX"])       // replaced the empty starter
        #expect(store.addTemplate(key: "VX") == nil)
        let vx = try #require(store.templates.first { $0.key == "VX" })
        #expect(!store.canAdd(vx))
        #expect(store.addTemplate(key: "no-such-template") == nil)
    }

    @Test func eachComponentCopyGetsItsOwnIDs() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(library: try Fixture.bundledLibrary(), at: url)
        store.addTemplate(key: "VX")
        let a = try #require(store.addTemplate(key: "COMP"))
        let b = try #require(store.addTemplate(key: "COMP"))
        #expect(a != b)
        let harnessIDs = store.harnesses.map(\.id)
        #expect(Set(harnessIDs).count == harnessIDs.count)
        let plugIDs = store.harnesses.flatMap { $0.connectors.map(\.id) }
        #expect(Set(plugIDs).count == plugIDs.count)
        #expect(store.harness(id: a)?.kind == .component)
    }

    @Test func editingACopyNeverChangesTheTemplate() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(library: try Fixture.bundledLibrary(), at: url)
        store.addTemplate(key: "VX")
        let plugID = try #require(store.active.connectors.first?.id)
        let original = try #require(store.templates.first { $0.key == "VX" }?.harness.connectors.first?.name)
        store.updatePlug(id: plugID) { $0.name = "Changed by the user" }
        #expect(store.active.connectors[0].name == "Changed by the user")
        #expect(store.templates.first { $0.key == "VX" }?.harness.connectors.first?.name == original)
    }

    // MARK: saving

    @Test func changesSurviveRelaunch() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(at: url)
        store.addPlug(Fixture.connector("x", name: "Horn", pins: Fixture.pins(3)), toHarness: "H1")
        store.renameHarness(id: "H1", to: "Dash")
        #expect(store.saveError == nil)

        let reopened = HarnessStore(fileURL: url, library: Fixture.emptyLibrary)
        #expect(reopened.state == store.state)
        #expect(reopened.active.title == "Dash")
        #expect(reopened.active.connectors.first?.name == "Horn")
    }

    @Test func anUnreadableSaveFileIsKeptAndTheAppStartsFresh() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("this is not json".utf8).write(to: url)

        let store = HarnessStore(fileURL: url, library: Fixture.emptyLibrary)
        #expect(store.isBlank)
        #expect(store.loadError != nil)
        let backup = url.deletingLastPathComponent().appendingPathComponent("state.unreadable.json")
        #expect(FileManager.default.fileExists(atPath: backup.path))
        let kept = try String(contentsOf: backup, encoding: .utf8)
        #expect(kept == "this is not json")
    }

    @Test func aSaveFileWithNoHarnessesStartsFresh() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(AppState(harnesses: [], activeID: "x"), at: url)
        #expect(store.isBlank)
    }

    // MARK: ids

    @Test func nextNumberFindsTheFirstFreeNumber() {
        #expect(HarnessStore.nextNumber(prefix: "MY-", in: []) == 1)
        #expect(HarnessStore.nextNumber(prefix: "MY-", in: ["MY-01", "MY-03"]) == 4)
        #expect(HarnessStore.nextNumber(prefix: "H", in: ["H1", "H2", "Other", "Hx"]) == 3)
        #expect(HarnessStore.nextNumber(prefix: "MY-", in: ["VX-EH-01"]) == 1)
    }
}
