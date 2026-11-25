//
//  AssistantPanel.swift
//  Harness Builder
//
//  The chat with the assistant, as an overlay on the drawing. Collapsed it is
//  a slim tab on the right edge (with a dot when a proposal is waiting), so the
//  harness stays in view; expanded it is a panel along the bottom. The
//  conversation lives in the session, so collapsing never loses it. The
//  assistant only proposes: changes happen from the review screen.
//

import SwiftUI

struct AssistantPanel: View {
    let session: AIChatSession
    @Binding var expanded: Bool
    let onReview: (UUID) -> Void

    @State private var text = ""
    @FocusState private var typing: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            if expanded {
                panel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                HStack {
                    Spacer()
                    edgeTab
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: expanded)
    }

    // MARK: collapsed

    private var edgeTab: some View {
        Button {
            expanded = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                Text("ASSISTANT")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .fixedSize()
                    .rotationEffect(.degrees(90))
                    .frame(width: 14, height: 84)
            }
            .foregroundStyle(Palette.amberText)
            .padding(.vertical, 12)
            .frame(width: 30)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14)
                    .fill(Palette.amber)
            )
            .overlay(alignment: .topLeading) {
                if session.hasProposal {
                    Circle()
                        .fill(Palette.warnStrong)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Palette.amber, lineWidth: 2))
                        .offset(x: -4, y: -4)
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 4, x: -1, y: 1)
        }
        .accessibilityLabel(session.hasProposal ? "Assistant, a proposal is waiting" : "Assistant")
    }

    // MARK: expanded

    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(Palette.amberInk)
                Text("Assistant")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                if !session.messages.isEmpty {
                    Button {
                        session.clear()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Palette.chipText)
                            .frame(width: 34, height: 30)
                            .background(Capsule().fill(Palette.chipFill))
                    }
                    .accessibilityLabel("Clear conversation")
                }
                Button {
                    typing = false
                    expanded = false
                } label: {
                    Image(systemName: "chevron.right.2")
                        .foregroundStyle(Palette.chipText)
                        .frame(width: 34, height: 30)
                        .background(Capsule().fill(Palette.chipFill))
                }
                .accessibilityLabel("Collapse assistant")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            Divider().overlay(Palette.divider)

            messageList

            Divider().overlay(Palette.divider)
            inputRow
        }
        .frame(height: 340)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .fill(Palette.sheetBg)
                .shadow(color: .black.opacity(0.25), radius: 8, y: -2)
        )
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .stroke(Palette.cardStroke, lineWidth: 1)
        )
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if session.messages.isEmpty {
                        Text("Describe a plug or how things connect and I'll propose changes. Nothing changes until you review and apply it.")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.nameText)
                            .padding(.top, 4)
                    }
                    ForEach(session.messages) { m in
                        bubble(m).id(m.id)
                    }
                    if session.busy {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Thinking…")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.nameText)
                        }
                        .id("busy")
                    }
                    if let err = session.errorText {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.warnText)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.warnFill))
                            .id("error")
                    }
                }
                .padding(14)
            }
            .onChange(of: session.messages.count) { _, _ in scrollToEnd(proxy) }
            .onChange(of: session.busy) { _, _ in scrollToEnd(proxy) }
            .onChange(of: session.errorText) { _, _ in scrollToEnd(proxy) }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation {
            if session.errorText != nil { proxy.scrollTo("error", anchor: .bottom) }
            else if session.busy { proxy.scrollTo("busy", anchor: .bottom) }
            else if let last = session.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

    @ViewBuilder
    private func bubble(_ m: AIChatSession.Message) -> some View {
        let mine = m.role == .user
        VStack(alignment: mine ? .trailing : .leading, spacing: 6) {
            Text(m.text)
                .font(.system(size: 14))
                .foregroundStyle(mine ? Palette.amberText : Palette.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 14).fill(mine ? Palette.amber : Palette.field))
                .textSelection(.enabled)
            if let proposal = m.proposal {
                Button {
                    onReview(m.id)
                } label: {
                    let n = proposal.changes.count
                    Text("Review \(n) change\(n == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.amberText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Palette.amber))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }

    private var inputRow: some View {
        let blank = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .focused($typing)
                .font(.system(size: 15))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.field))
            Button {
                let sent = text
                text = ""
                Task { await session.send(sent) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(blank || session.busy ? Palette.chipFill : Palette.amber)
            }
            .disabled(blank || session.busy)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
