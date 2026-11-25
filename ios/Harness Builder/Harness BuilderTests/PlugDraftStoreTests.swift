//
//  PlugDraftStoreTests.swift
//  Harness BuilderTests
//
//  The unsaved-plug draft: kept on the device, resumed, cleared, and dropped
//  when it no longer makes sense.
//

import Foundation
import Testing
@testable import Harness_Builder

@MainActor
struct PlugDraftStoreTests {
    private func makeStore() throws -> (HarnessStore, URL) {
        let state = AppState(harnesses: [Fixture.harness("H1", plugs: [Fixture.connector("A", pins: Fixture.pins(3))])], activeID: "H1")
        let url = Fixture.tempFileURL()
        return (try Fixture.store(state, at: url), url)
    }

    private func newPlugDraft() -> PlugDraft {
        var d = PlugDraft(newShape: "rectangular-block")
        d.name = "Fuel pump"
        d.pins[0].color = "GRN/WHT"
        d.pins[0].role = "power"
        d.connect(pin: 0, toPlug: "A", pinNumber: 2, targetPin: Fixture.pin(2))
        return d
    }

    @Test func aSavedDraftComesBackAsItWas() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let saved = SavedPlugDraft(harnessID: "H1", editingID: nil, sel: 2, draft: newPlugDraft())
        store.saveDraft(saved)
        #expect(store.savedDraft() == saved)
    }

    @Test func aDraftIsKeptAcrossARelaunch() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        store.saveDraft(SavedPlugDraft(harnessID: "H1", editingID: nil, sel: 0, draft: newPlugDraft()))
        let reopened = HarnessStore(fileURL: url, library: Fixture.emptyLibrary)
        #expect(reopened.savedDraft()?.draft.name == "Fuel pump")
    }

    @Test func clearingRemovesTheDraft() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        store.saveDraft(SavedPlugDraft(harnessID: "H1", editingID: nil, sel: 0, draft: newPlugDraft()))
        store.clearDraft()
        #expect(store.savedDraft() == nil)
        #expect(!FileManager.default.fileExists(atPath: store.draftURL.path))
    }

    @Test func noDraftMeansNothingToResume() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        #expect(store.savedDraft() == nil)
    }

    @Test func aDraftForAnEditedPlugKeepsItsPinsAndLayout() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        let plug = try #require(store.plug(id: "A")?.connector)
        var d = PlugDraft(editing: plug)
        d.pins[1].color = "BLU"
        store.saveDraft(SavedPlugDraft(harnessID: "H1", editingID: "A", sel: 1, draft: d))
        let back = try #require(store.savedDraft())
        #expect(back.editingID == "A")
        #expect(back.draft.pins[1].color == "BLU")
        #expect(back.draft.fixedRows?.count == plug.rows.count)
        #expect(back.draft.hasChanges)
    }

    @Test func aDraftForADeletedHarnessIsDropped() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        store.saveDraft(SavedPlugDraft(harnessID: "GONE", editingID: nil, sel: 0, draft: newPlugDraft()))
        #expect(store.savedDraft() == nil)
        #expect(!FileManager.default.fileExists(atPath: store.draftURL.path))
    }

    @Test func aDraftForARemovedPlugIsDropped() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        store.saveDraft(SavedPlugDraft(harnessID: "H1", editingID: "NOPE", sel: 0, draft: newPlugDraft()))
        #expect(store.savedDraft() == nil)
    }

    @Test func anUnreadableDraftIsDroppedWithoutHarmingTheData() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        try Data("not json".utf8).write(to: store.draftURL)
        #expect(store.savedDraft() == nil)
        #expect(!FileManager.default.fileExists(atPath: store.draftURL.path))
        #expect(store.harnesses.count == 1)
    }

    @Test func theDraftIsNotPartOfABackup() throws {
        let (store, url) = try makeStore()
        defer { Fixture.cleanup(url) }
        store.saveDraft(SavedPlugDraft(harnessID: "H1", editingID: nil, sel: 0, draft: newPlugDraft()))
        let text = String(decoding: try store.backupData(), as: UTF8.self)
        #expect(!text.contains("Fuel pump"))
    }

    @Test func aFreshDraftHasNoChangesSoItIsNotWorthKeeping() {
        #expect(!PlugDraft(newShape: "rectangular-block").hasChanges)
    }
}
