//
//  AIUndoTests.swift
//  Harness BuilderTests
//
//  Applying a preview and undoing it: the snapshot, the refusals, and what
//  undo never touches.
//

import Foundation
import Testing
@testable import Harness_Builder

@MainActor
struct AIUndoTests {
    private func makeStore() throws -> (HarnessStore, URL) {
        let a = Fixture.connector("A", name: "Alpha", pins: Fixture.pins(3))
        let c = Fixture.connector("C", name: "Charlie", pins: Fixture.pins(2))
        let s = AppState(harnesses: [Fixture.harness("H1", plugs: [a]), Fixture.harness("H2", plugs: [c])], activeID: "H1")
        let url = Fixture.tempFileURL()
        return (try Fixture.store(s, at: url), url)
    }

    private func preview(_ store: HarnessStore, _ changes: [AIChange]? = nil) -> ProposalPreview {
        let list = changes ?? [.setPin(plug: "A", pin: 1, color: "BLU", function: nil, role: nil, gauge: nil)]
        return ProposalEngine.preview(AIProposal(summary: "Make A1 blue", changes: list), on: store.state, harnessID: "H1")
    }

    @Test func applyingChangesTheDataAndUndoPutsItBack() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let before = store.state
        #expect(store.applyAI(preview(store)))
        #expect(store.plug(id: "A")?.connector.flatPins[0].pin.color == "BLU")
        #expect(store.aiUndoRecord()?.summary == "Make A1 blue")
        #expect(store.undoAI())
        #expect(store.state.harnesses == before.harnesses)
        #expect(store.aiUndoRecord() == nil)
    }

    @Test func appliedChangesAreSavedToDisk() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        store.applyAI(preview(store))
        let reopened = HarnessStore(fileURL: url, library: Fixture.emptyLibrary)
        #expect(reopened.plug(id: "A")?.connector.flatPins[0].pin.color == "BLU")
        #expect(reopened.aiUndoRecord() != nil)
    }

    @Test func aPreviewWithErrorsIsNeverApplied() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let before = store.state
        let bad = preview(store, [.setPin(plug: "A", pin: 1, color: "PURPLE", function: nil, role: nil, gauge: nil)])
        #expect(!store.applyAI(bad))
        #expect(store.state == before)
        #expect(store.aiUndoRecord() == nil)
    }

    @Test func aPreviewThatDoesNothingIsNotApplied() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let same = preview(store, [.setPin(plug: "A", pin: 1, color: "RED", function: nil, role: nil, gauge: nil)])
        #expect(!store.applyAI(same))
        #expect(store.aiUndoRecord() == nil)
    }

    @Test func aStalePreviewIsRefused() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let p = preview(store)
        store.updatePlug(id: "A") { $0.name = "Renamed" }          // the user edited after the preview was made
        let edited = store.state
        #expect(!store.applyAI(p))
        #expect(store.state == edited)
    }

    @Test func undoIsRefusedOnceYouHaveEditedByHand() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        store.applyAI(preview(store))
        store.updatePlug(id: "A") { $0.name = "Mine" }
        #expect(store.aiUndoRecord() == nil)
        #expect(!store.undoAI())
        #expect(store.plug(id: "A")?.connector.name == "Mine")
        #expect(store.plug(id: "A")?.connector.flatPins[0].pin.color == "BLU")
    }

    @Test func switchingTabsDoesNotBlockUndoAndIsKept() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        store.applyAI(preview(store))
        store.setActive("H2")
        #expect(store.aiUndoRecord() != nil)
        #expect(store.undoAI())
        #expect(store.state.activeID == "H2")
        #expect(store.plug(id: "A")?.connector.flatPins[0].pin.color == "RED")
    }

    @Test func applyingKeepsTheHarnessYouHaveOpen() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let p = preview(store)
        store.setActive("H2")                 // switching tabs doesn't change the harnesses, so the preview is still good
        #expect(store.applyAI(p))
        #expect(store.state.activeID == "H2")
    }

    @Test func aSecondApplyReplacesTheUndoPoint() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        store.applyAI(preview(store))
        let afterFirst = store.state
        let second = preview(store, [.setPin(plug: "A", pin: 2, color: "GRN", function: nil, role: nil, gauge: nil)])
        #expect(store.applyAI(second))
        #expect(store.undoAI())
        #expect(store.state.harnesses == afterFirst.harnesses)
    }

    @Test func theUndoSnapshotIsNotPartOfABackup() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        store.applyAI(preview(store))
        let text = String(decoding: try store.backupData(), as: UTF8.self)
        #expect(!text.contains("Make A1 blue"))
    }
}
