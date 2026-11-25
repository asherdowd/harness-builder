//
//  HarnessStore.swift
//  Harness Builder
//
//  Holds the user's harnesses and saves them on the device (a JSON file in
//  Application Support). Every change is saved right away.
//

import Foundation
import Observation

/// A plug together with the harness it sits on.
struct PlugRef: Identifiable, Hashable {
    var harness: Harness
    var connector: Connector
    var id: String { connector.id }
}

@MainActor
@Observable
final class HarnessStore {
    private(set) var state: AppState
    let templates: [Template]
    private(set) var loadError: String?
    private(set) var saveError: String?
    let fileURL: URL

    // MARK: setup

    nonisolated static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("HarnessBuilder", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    init(fileURL: URL = HarnessStore.defaultFileURL, library: TemplateLibrary? = nil) {
        self.fileURL = fileURL
        var errors: [String] = []

        var loadedTemplates: [Template] = []
        if let library {
            loadedTemplates = library.templates
        } else {
            do {
                loadedTemplates = try TemplateLibrary.loadFromBundle().templates
            } catch {
                errors.append("Templates: \(error.localizedDescription)")
            }
        }
        templates = loadedTemplates

        var loaded: AppState?
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let s = try JSONDecoder().decode(AppState.self, from: data)
                if !s.harnesses.isEmpty { loaded = s }
            } catch {
                // Keep the unreadable file so nothing is lost, then start fresh.
                let backup = fileURL.deletingLastPathComponent().appendingPathComponent("state.unreadable.json")
                try? FileManager.default.removeItem(at: backup)
                try? FileManager.default.moveItem(at: fileURL, to: backup)
                errors.append("Saved data couldn't be read, so a copy was kept as state.unreadable.json. (\(error.localizedDescription))")
            }
        }
        state = loaded ?? .blank()
        loadError = errors.isEmpty ? nil : errors.joined(separator: "\n")
    }

    // MARK: saving

    private func commit(_ change: (inout AppState) -> Void) {
        change(&state)
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(state).write(to: fileURL, options: .atomic)
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: backup and restore

    enum BackupError: LocalizedError {
        case empty
        var errorDescription: String? {
            "That file has no harnesses in it."
        }
    }

    /// The whole saved state as readable JSON.
    func backupData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(state)
    }

    /// Writes a dated backup file in a temporary folder, ready to share or save.
    func writeBackupFile(date: Date = Date()) throws -> URL {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Backup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("Harness Builder backup \(f.string(from: date)).json")
        try backupData().write(to: url, options: .atomic)
        return url
    }

    /// Reads a backup file. Throws if it isn't a Harness Builder backup or holds no harnesses.
    static func decodeBackup(_ data: Data) throws -> AppState {
        let s = try JSONDecoder().decode(AppState.self, from: data)
        guard !s.harnesses.isEmpty else { throw BackupError.empty }
        return s
    }

    /// Replaces everything with a backup. What was here is kept next to it as
    /// state.before-restore.json in case the restore was a mistake.
    func restore(_ backup: AppState) {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? backupData() {
            try? data.write(to: dir.appendingPathComponent("state.before-restore.json"), options: .atomic)
        }
        var next = backup
        if !next.harnesses.contains(where: { $0.id == next.activeID }) {
            next.activeID = next.harnesses[0].id
        }
        commit { $0 = next }
    }

    /// Swaps in a whole new state and saves it. Used by the AI apply and undo,
    /// which have already checked that the new state is what the user approved.
    func replaceState(_ next: AppState) {
        commit { $0 = next }
    }

    // MARK: reading

    var harnesses: [Harness] { state.harnesses }

    /// The open harness. The list is never empty, so this always exists.
    var active: Harness {
        state.harnesses.first { $0.id == state.activeID } ?? state.harnesses[0]
    }

    /// True while the user still has only the empty starter harness.
    var isBlank: Bool {
        state.harnesses.count == 1 && state.harnesses[0].connectors.isEmpty && state.harnesses[0].tab == nil
    }

    func harness(id: String) -> Harness? {
        state.harnesses.first { $0.id == id }
    }

    func plug(id: String) -> PlugRef? {
        for h in state.harnesses {
            if let c = h.connectors.first(where: { $0.id == id }) { return PlugRef(harness: h, connector: c) }
        }
        return nil
    }

    /// Where a plug is linked to, if the target still exists.
    func linkTarget(of connector: Connector) -> PlugRef? {
        guard let link = connector.link else { return nil }
        return plug(id: link.cid)
    }

    /// Plugs whose link points at this plug (shown as "Linked component").
    func linkedComponents(to connectorID: String) -> [PlugRef] {
        state.harnesses.flatMap { h in
            h.connectors.filter { $0.link?.cid == connectorID }.map { PlugRef(harness: h, connector: $0) }
        }
    }

    /// Plugs a link can point at: everything on other harnesses.
    func linkCandidates(excludingHarness hid: String) -> [PlugRef] {
        state.harnesses.filter { $0.id != hid }.flatMap { h in
            h.connectors.map { PlugRef(harness: h, connector: $0) }
        }
    }

    func canAdd(_ template: Template) -> Bool {
        template.repeatable || !state.harnesses.contains { $0.id == template.key }
    }

    // MARK: harness actions

    func setActive(_ id: String) {
        guard state.harnesses.contains(where: { $0.id == id }) else { return }
        commit { $0.activeID = id }
    }

    /// Back to the blank first-open state.
    func resetAll() {
        commit { $0 = .blank() }
    }

    /// "Try the example": loads the example harnesses as editable copies.
    func loadExample() {
        let loaded = TemplateLibrary.exampleKeys.compactMap { key in templates.first { $0.key == key }?.harness }
        guard !loaded.isEmpty else { return }
        commit { $0 = AppState(harnesses: loaded, activeID: loaded[0].id) }
    }

    /// "Create a harness". Returns the new harness id, or nil when the empty
    /// starter harness is simply kept as the user's first harness.
    @discardableResult
    func createHarness() -> String? {
        if isBlank { return nil }
        let id = "H\(Self.nextNumber(prefix: "H", in: state.harnesses.map(\.id)))"
        let title = "Harness \(state.harnesses.count + 1)"
        commit {
            $0.harnesses.append(Harness(id: id, title: title, tab: nil, kind: .harness, connectors: []))
            $0.activeID = id
        }
        return id
    }

    /// Adds a copy of a template. Returns the new harness id, or nil if it can't be added.
    @discardableResult
    func addTemplate(key: String) -> String? {
        guard let template = templates.first(where: { $0.key == key }), canAdd(template) else { return nil }
        var h = template.harness
        let base = isBlank ? [] : state.harnesses

        if template.repeatable {
            // Give each copy its own ids so copies never collide.
            h.id = "C\(Self.nextNumber(prefix: "C", in: base.map(\.id)))"
            let allPlugIDs = base.flatMap { $0.connectors.map(\.id) }
            var next = Self.nextNumber(prefix: "CMP-", in: allPlugIDs)
            for i in h.connectors.indices {
                h.connectors[i].id = "CMP-" + String(format: "%02d", next)
                next += 1
            }
        }
        commit {
            $0.harnesses = base + [h]
            $0.activeID = h.id
        }
        return h.id
    }

    func renameHarness(id: String, to title: String) {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        commit { s in
            guard let i = s.harnesses.firstIndex(where: { $0.id == id }) else { return }
            s.harnesses[i].title = name
            s.harnesses[i].tab = name
        }
    }

    func deleteHarness(id: String) {
        commit { s in
            let wasActive = s.activeID == id
            s.harnesses.removeAll { $0.id == id }
            if s.harnesses.isEmpty {
                s = .blank()
            } else if wasActive {
                s.activeID = s.harnesses[0].id
            }
        }
    }

    // MARK: plug actions

    /// Adds a plug the user built. The draft's id is replaced. Returns the new id.
    @discardableResult
    func addPlug(_ draft: Connector, toHarness hid: String) -> String? {
        guard let hi = state.harnesses.firstIndex(where: { $0.id == hid }) else { return nil }
        let allIDs = state.harnesses.flatMap { $0.connectors.map(\.id) }
        let id = "MY-" + String(format: "%02d", Self.nextNumber(prefix: "MY-", in: allIDs))
        var c = draft
        c.id = id
        c.custom = true
        if c.name.trimmingCharacters(in: .whitespaces).isEmpty {
            c.name = "Plug \(state.harnesses[hi].connectors.count + 1)"
        }
        Self.recount(&c)
        commit { $0.harnesses[hi].connectors.append(c) }
        return id
    }

    /// Changes one plug wherever it is.
    func updatePlug(id: String, _ change: (inout Connector) -> Void) {
        commit { s in
            for hi in s.harnesses.indices {
                if let ci = s.harnesses[hi].connectors.firstIndex(where: { $0.id == id }) {
                    change(&s.harnesses[hi].connectors[ci])
                    Self.recount(&s.harnesses[hi].connectors[ci])
                    return
                }
            }
        }
    }

    func removePlug(id: String) {
        commit { s in
            for hi in s.harnesses.indices {
                s.harnesses[hi].connectors.removeAll { $0.id == id }
            }
        }
    }

    /// Writes connections chosen in the wizard onto the pins at the other end.
    /// A pin that already has a net is left alone.
    func stampNets(_ stamps: [NetStamp]) {
        guard !stamps.isEmpty else { return }
        commit { s in
            for st in stamps {
                for hi in s.harnesses.indices {
                    guard let ci = s.harnesses[hi].connectors.firstIndex(where: { $0.id == st.plugID }) else { continue }
                    var n = 0
                    for ri in s.harnesses[hi].connectors[ci].rows.indices {
                        for pi in s.harnesses[hi].connectors[ci].rows[ri].pins.indices {
                            n += 1
                            guard n == st.pinNumber else { continue }
                            if (s.harnesses[hi].connectors[ci].rows[ri].pins[pi].netId ?? "").isEmpty {
                                s.harnesses[hi].connectors[ci].rows[ri].pins[pi].netId = st.net
                                s.harnesses[hi].connectors[ci].rows[ri].pins[pi].netType = st.netType
                            }
                        }
                    }
                }
            }
        }
    }

    /// Moves a plug up (-1) or down (+1) along its harness.
    func movePlug(id: String, by delta: Int) {
        commit { s in
            for hi in s.harnesses.indices {
                guard let i = s.harnesses[hi].connectors.firstIndex(where: { $0.id == id }) else { continue }
                let j = i + delta
                guard s.harnesses[hi].connectors.indices.contains(j) else { return }
                s.harnesses[hi].connectors.swapAt(i, j)
                return
            }
        }
    }

    /// Links a plug to a plug on another harness, or clears the link with nil.
    func setLink(from connectorID: String, to link: PlugLink?) {
        updatePlug(id: connectorID) { $0.link = link }
    }

    // MARK: helpers

    private static func recount(_ c: inout Connector) {
        let pins = c.rows.flatMap(\.pins)
        c.totalPositions = pins.count
        c.populatedPositions = pins.filter(\.populated).count
    }

    /// Next unused number for ids like "H2", "MY-03", "CMP-01".
    static func nextNumber(prefix: String, in ids: [String]) -> Int {
        let numbers = ids.compactMap { id -> Int? in
            guard id.hasPrefix(prefix) else { return nil }
            return Int(id.dropFirst(prefix.count))
        }
        return (numbers.max() ?? 0) + 1
    }
}
