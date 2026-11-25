//
//  PlugDraftStore.swift
//  Harness Builder
//
//  Keeps the plug being built in the wizard on the device while the user works,
//  so closing or losing the app doesn't lose it. It lives in its own small
//  file next to the saved data, so it is not part of the harnesses or a backup.
//  The wizard writes it as you edit and clears it on Save or Discard; the main
//  screen offers to resume it the next time the app opens.
//

import Foundation

/// A plug in progress: the draft plus where it belongs.
struct SavedPlugDraft: Codable, Equatable {
    var harnessID: String
    /// The plug being edited, or nil when building a new one.
    var editingID: String?
    /// The pin the editor was on (0-based).
    var sel: Int
    var draft: PlugDraft
}

extension HarnessStore {
    var draftURL: URL {
        fileURL.deletingLastPathComponent().appendingPathComponent("plug-draft.json")
    }

    /// The saved draft, if there is one that still makes sense. A draft whose
    /// harness or plug is gone, or that can't be read, is removed.
    func savedDraft() -> SavedPlugDraft? {
        guard FileManager.default.fileExists(atPath: draftURL.path) else { return nil }
        guard let data = try? Data(contentsOf: draftURL),
              let saved = try? JSONDecoder().decode(SavedPlugDraft.self, from: data),
              harnesses.contains(where: { $0.id == saved.harnessID }),
              saved.editingID.map({ plug(id: $0) != nil }) ?? true
        else {
            clearDraft()
            return nil
        }
        return saved
    }

    func saveDraft(_ saved: SavedPlugDraft) {
        do {
            try FileManager.default.createDirectory(at: draftURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(saved).write(to: draftURL, options: .atomic)
        } catch {
            // A draft that can't be kept is not worth interrupting the user for.
        }
    }

    func clearDraft() {
        try? FileManager.default.removeItem(at: draftURL)
    }
}
