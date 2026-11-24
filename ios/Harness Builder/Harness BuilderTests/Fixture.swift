//
//  Fixture.swift
//  Harness BuilderTests
//
//  Small builders shared by the tests so each test reads as a story.
//

import Foundation
@testable import Harness_Builder

@MainActor
enum Fixture {
    static func pin(_ n: Int,
                    color: String? = "RED",
                    guess: String? = "Signal",
                    netId: String? = nil,
                    netType: String? = nil,
                    populated: Bool = true,
                    role: String? = nil,
                    gauge: Int? = nil) -> Pin {
        Pin(position: n, populated: populated, color: color, guess: guess, confidence: "High",
            netId: netId, netType: netType, role: role, gauge: gauge)
    }

    /// `count` wired pins numbered 1...count.
    static func pins(_ count: Int) -> [Pin] {
        (1...max(count, 1)).prefix(count).map { pin($0) }
    }

    /// A plug whose pins are split into rows of `perRow` (all in one row when nil).
    static func connector(_ id: String,
                          name: String = "Plug",
                          shape: String = "rectangular-block",
                          pins: [Pin],
                          perRow: Int? = nil,
                          sameCircuitAs: [String]? = nil,
                          link: PlugLink? = nil) -> Connector {
        let size = perRow ?? max(pins.count, 1)
        var rows: [Row] = []
        var i = 0
        while i < pins.count {
            let slice = Array(pins[i..<min(i + size, pins.count)])
            rows.append(Row(row: rows.count + 1, positions: slice.count, pins: slice))
            i += size
        }
        return Connector(id: id, name: name, shape: shape, rows: rows, sameCircuitAs: sameCircuitAs, link: link)
    }

    static func harness(_ id: String,
                        title: String? = nil,
                        kind: HarnessKind = .harness,
                        plugs: [Connector] = []) -> Harness {
        Harness(id: id, title: title ?? "Harness \(id)", tab: nil, kind: kind, connectors: plugs)
    }

    static var emptyLibrary: TemplateLibrary {
        TemplateLibrary(version: 1, templates: [])
    }

    /// The real bundled templates (the app is the test host, so its resources are available).
    static func bundledLibrary() throws -> TemplateLibrary {
        try TemplateLibrary.loadFromBundle(Bundle(for: HarnessStore.self))
    }

    static func tempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("hb-test-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    /// A store saving to a throwaway file, optionally starting from `state`.
    static func store(_ state: AppState? = nil,
                      library: TemplateLibrary? = nil,
                      at fileURL: URL? = nil) throws -> HarnessStore {
        let url = fileURL ?? tempFileURL()
        if let state {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: url)
        }
        return HarnessStore(fileURL: url, library: library ?? emptyLibrary)
    }

    static func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
