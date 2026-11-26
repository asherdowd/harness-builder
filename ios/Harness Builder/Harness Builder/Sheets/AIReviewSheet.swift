//
//  AIReviewSheet.swift
//  Harness Builder
//
//  Shows exactly what an assistant proposal would do, using the same rules as
//  the rest of the app: values it would replace, pins it would move off a
//  wire, and problems "Check this harness" would newly report. If anything is
//  flagged, the user has to tick a box before Apply is enabled. Applying saves
//  an undo point first.
//

import SwiftUI

struct AIReviewSheet: View {
    let store: HarnessStore
    let session: AIChatSession
    let messageID: UUID
    let onClose: () -> Void
    /// Called after a successful apply, with the proposal's summary.
    let onApplied: (String) -> Void

    @State private var preview: ProposalPreview?
    @State private var confirmed = false
    @State private var failed: String?

    private var message: AIChatSession.Message? { session.messages.first { $0.id == messageID } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Review changes")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Button("Not now") { notNow() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.chipText)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 10)

            Rectangle()
                .fill(Palette.divider)
                .frame(height: 1)

            if let p = preview {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if !p.proposal.summary.isEmpty {
                            Text(p.proposal.summary)
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.text)
                        }
                        if !p.errors.isEmpty {
                            card("Can't apply this", warn: true, lines: p.errors)
                        } else {
                            content(p)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
                .overlay(alignment: .top) {
                    LinearGradient(colors: [Palette.sheetBg, Palette.sheetBg.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 12)
                        .allowsHitTesting(false)
                }
                footer(p)
            } else {
                Spacer()
                Text("This proposal is no longer available.")
                    .foregroundStyle(Palette.nameText)
                Spacer()
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard preview == nil, let proposal = message?.proposal else { return }
        preview = session.preview(proposal)
    }

    // MARK: content

    @ViewBuilder
    private func content(_ p: ProposalPreview) -> some View {
        if !p.newPlugs.isEmpty { card("New plugs", lines: p.newPlugs) }
        if !p.connections.isEmpty { card("Connections", lines: p.connections) }

        let overwrites = p.overwrites
        if !overwrites.isEmpty {
            card("Replaces existing values", warn: true, lines: overwrites.map(describe))
        }
        let others = p.fieldChanges.filter { !$0.isOverwrite }
        if !others.isEmpty {
            card("Fills in", lines: others.map(describe))
        }
        if !p.rewires.isEmpty {
            card("Moves pins off a wire", warn: true, lines: p.rewires.map {
                "\($0.plugTitle) pin \($0.pin) leaves its wire. \($0.left) other pin\($0.left == 1 ? "" : "s") stay on it."
            })
        }
        if !p.newIssues.isEmpty {
            card("Would add to Check this harness", warn: !p.newProblems.isEmpty,
                 lines: p.newIssues.map { "\($0.title): \($0.detail)" })
        }
        Text("Pins the assistant fills in are marked Guess until you confirm them.")
            .font(.system(size: 12))
            .foregroundStyle(Palette.nameText)
    }

    private func describe(_ c: FieldChange) -> String {
        if let before = c.before, !before.isEmpty {
            return "\(c.plugTitle) pin \(c.pin) · \(c.field): \(before) → \(c.after)"
        }
        return "\(c.plugTitle) pin \(c.pin) · \(c.field): \(c.after)"
    }

    private func card(_ title: String, warn: Bool = false, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(warn ? Palette.warnText : Palette.nameText)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 14))
                    .foregroundStyle(warn ? Palette.warnText : Palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(warn ? Palette.warnFill : Palette.field))
    }

    // MARK: footer

    private func footer(_ p: ProposalPreview) -> some View {
        VStack(spacing: 10) {
            Divider().overlay(Palette.divider)
            if let failed {
                Text(failed)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.warnText)
                    .padding(.horizontal, 18)
            }
            if p.canApply && p.needsConfirmation {
                Button {
                    confirmed.toggle()
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: confirmed ? "checkmark.square.fill" : "square")
                            .foregroundStyle(confirmed ? Palette.amberInk : Palette.nameText)
                        Text("I've looked at what would be replaced, moved or flagged.")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.text)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18)
                }
                .buttonStyle(.plain)
            }
            let n = p.proposal.changes.count
            Button {
                apply(p)
            } label: {
                Text("Apply \(n) change\(n == 1 ? "" : "s")")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.amberText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Palette.amber))
            }
            .disabled(!p.canApply || (p.needsConfirmation && !confirmed))
            .opacity(!p.canApply || (p.needsConfirmation && !confirmed) ? 0.4 : 1)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
    }

    private func apply(_ p: ProposalPreview) {
        if store.applyAI(p) {
            session.dismissProposal(on: messageID)
            onApplied(p.proposal.summary)
            onClose()
        } else {
            failed = "Something changed since this was proposed, so nothing was applied. Ask again and review the new proposal."
            session.dismissProposal(on: messageID)
        }
    }

    private func notNow() {
        session.dismissProposal(on: messageID)
        onClose()
    }
}
