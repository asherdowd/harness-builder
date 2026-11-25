//
//  BackupAndCSVTests.swift
//  Harness BuilderTests
//
//  Backup and restore, the CSV wire list, and used/spare pin counts.
//

import Foundation
import Testing
@testable import Harness_Builder

@MainActor
struct BackupAndCSVTests {
    private func state() -> AppState {
        let a = Fixture.connector("A", name: "Plug A", pins: [
            Fixture.pin(1, color: "RED", guess: "Fuel, pump", netId: "N1", netType: "wire", gauge: 18),
            Fixture.pin(2, populated: false),
            Fixture.pin(3, color: "BLK/WHT", guess: "Says \"hi\"", role: "ground"),
        ])
        let b = Fixture.connector("B", name: "Plug B", pins: [Fixture.pin(1, color: "RED", guess: "Fuel", netId: "N1", netType: "wire")])
        return AppState(harnesses: [Fixture.harness("H1", title: "Engine", plugs: [a]),
                                    Fixture.harness("H2", title: "Firewall", plugs: [b])], activeID: "H2")
    }

    // MARK: counts

    @Test func wiredAndSparePinsAddUpToThePlug() {
        let c = state().harnesses[0].connectors[0]
        #expect(c.wiredCount == 2)
        #expect(c.spareCount == 1)
        #expect(c.wiredCount + c.spareCount == c.flatPins.count)
    }

    // MARK: CSV

    @Test func csvHasAHeaderAndARowForEveryWire() {
        let lines = WireListCSV.csv(state().harnesses).components(separatedBy: "\r\n").filter { !$0.isEmpty }
        #expect(lines.first == WireListCSV.columns.joined(separator: ","))
        #expect(lines.count == 1 + 3)           // header + 2 wires on A + 1 on B (the empty pin has no row)
    }

    @Test func csvEscapesCommasAndQuotes() {
        #expect(WireListCSV.escape("plain") == "plain")
        #expect(WireListCSV.escape("a,b") == "\"a,b\"")
        #expect(WireListCSV.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(WireListCSV.escape("two\nlines") == "\"two\nlines\"")
    }

    @Test func csvNamesTheOtherEndOfAConnectedWire() {
        let s = state()
        let csv = WireListCSV.csv([s.harnesses[0]], allHarnesses: s.harnesses)
        #expect(csv.contains("Plug B · pin 1"))
    }

    @Test func csvOnlyKnowsAboutTheHarnessesItIsGiven() {
        let s = state()
        let csv = WireListCSV.csv([s.harnesses[0]])
        #expect(!csv.contains("Plug B"))
    }

    @Test func csvShowsGaugeAndWireType() {
        let csv = WireListCSV.csv(state().harnesses)
        #expect(csv.contains(",18,"))
        #expect(csv.contains("Ground"))
    }

    @Test func csvExportWritesAReadableFile() throws {
        let s = state()
        let urls = try HarnessExporter.export(s.harnesses, includeTable: false, format: .csv)
        let url = try #require(urls.first)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(url.pathExtension == "csv")
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.hasPrefix("Harness,Plug,Pin"))
    }

    @Test func aHarnessWithNoWiresStillGivesAHeader() {
        let csv = WireListCSV.csv([Fixture.harness("H1")])
        #expect(csv == WireListCSV.columns.joined(separator: ",") + "\r\n")
    }

    // MARK: backup and restore

    @Test func aBackupRoundTrips() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(state(), at: url)
        let data = try store.backupData()
        #expect(try HarnessStore.decodeBackup(data) == store.state)
    }

    @Test func aBackupFileHasADatedName() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(state(), at: url)
        let file = try store.writeBackupFile(date: Date(timeIntervalSince1970: 0))
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        #expect(file.lastPathComponent.hasPrefix("Harness Builder backup 19"))
        #expect(file.pathExtension == "json")
    }

    @Test func notABackupIsRejected() {
        #expect(throws: (any Error).self) { try HarnessStore.decodeBackup(Data("hello".utf8)) }
        #expect(throws: (any Error).self) { try HarnessStore.decodeBackup(Data("{\"harnesses\":[],\"activeID\":\"H1\"}".utf8)) }
    }

    @Test func restoreReplacesEverythingAndKeepsACopyOfWhatWasThere() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(at: url)              // the blank starter
        store.restore(state())
        #expect(store.harnesses.map(\.id) == ["H1", "H2"])
        #expect(store.active.id == "H2")
        let copy = url.deletingLastPathComponent().appendingPathComponent("state.before-restore.json")
        let kept = try HarnessStore.decodeBackup(Data(contentsOf: copy))
        #expect(kept == .blank())
    }

    @Test func restoreFixesAnActiveHarnessThatIsNotInTheBackup() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(at: url)
        var s = state()
        s.activeID = "GONE"
        store.restore(s)
        #expect(store.active.id == "H1")
    }

    @Test func aRestoredBackupSurvivesARelaunch() throws {
        let url = Fixture.tempFileURL(); defer { Fixture.cleanup(url) }
        let store = try Fixture.store(at: url)
        store.restore(state())
        let again = try Fixture.store(at: url)
        #expect(again.harnesses.count == 2)
    }
}
