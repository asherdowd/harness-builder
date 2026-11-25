//
//  AIUndo.swift
//  Harness Builder
//
//  Applying an AI proposal and undoing it. Before anything changes, the whole
//  state is written to ai-undo.json next to the saved data, so one tap puts
//  everything back. If the snapshot can't be written, nothing is applied.
//  Undo is only offered while the harnesses are exactly as the AI left them;
//  once you edit something by hand, undoing would also throw that away.
//

import Foundation

struct AIUndoRecord: Codable, Equatable {
    var before: AppState
    var after: AppState
    var summary: String
    var date: Date
}

extension HarnessStore {
    var aiUndoURL: URL {
        fileURL.deletingLastPathComponent().appendingPathComponent("ai-undo.json")
    }

    /// Applies an approved preview. Returns false, changing nothing, if the
    /// preview has errors, the data has changed since it was made, or the undo
    /// snapshot couldn't be saved.
    @discardableResult
    func applyAI(_ preview: ProposalPreview, date: Date = Date()) -> Bool {
        guard preview.canApply, let after = preview.after, preview.base.harnesses == state.harnesses else { return false }
        let record = AIUndoRecord(before: state, after: after, summary: preview.proposal.summary, date: date)
        do {
            try FileManager.default.createDirectory(at: aiUndoURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(record).write(to: aiUndoURL, options: .atomic)
        } catch {
            return false
        }
        var next = after
        if state.harnesses.contains(where: { $0.id == state.activeID }), after.harnesses.contains(where: { $0.id == state.activeID }) {
            next.activeID = state.activeID
        }
        replaceState(next)
        return true
    }

    /// The last AI change, if it can still be undone safely.
    func aiUndoRecord() -> AIUndoRecord? {
        guard let data = try? Data(contentsOf: aiUndoURL),
              let record = try? JSONDecoder().decode(AIUndoRecord.self, from: data),
              record.after.harnesses == state.harnesses
        else { return nil }
        return record
    }

    /// Puts everything back as it was before the last AI change.
    @discardableResult
    func undoAI() -> Bool {
        guard let record = aiUndoRecord() else { return false }
        var next = record.before
        if next.harnesses.contains(where: { $0.id == state.activeID }) { next.activeID = state.activeID }
        replaceState(next)
        clearAIUndo()
        return true
    }

    func clearAIUndo() {
        try? FileManager.default.removeItem(at: aiUndoURL)
    }
}
