//
//  ChecksSheet.swift
//  Harness Builder
//
//  The result of "Check this harness". Tap an item to jump to the plug.
//

import SwiftUI

struct ChecksSheet: View {
    let store: HarnessStore
    let onJump: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        let harness = store.active
        let issues = MapChecks.run(on: harness, in: store.harnesses)
        let problems = issues.filter { $0.severity == .problem }
        let notes = issues.filter { $0.severity == .note }

        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Check this harness")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Button("Done", action: onClose)
                        .font(.system(size: 14, weight: .semibold))
                        .tint(Palette.amberInk)
                }
                Text(harness.title)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.nameText)

                if issues.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(Palette.amberInk)
                        Text("Nothing looks wrong. Every wire has a color and a label, and every connection has another end.")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.text)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Palette.chipFill))
                } else {
                    group("LIKELY MISTAKES", problems)
                    group("WORTH A LOOK", notes)
                }

                Text("These checks only look for gaps in the map. They can't tell you whether the real wiring is right.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.nameText)
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Palette.sheetBg)
    }

    @ViewBuilder
    private func group(_ title: String, _ items: [MapIssue]) -> some View {
        if !items.isEmpty {
            Text("\(title) (\(items.count))")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.nameText)
                .padding(.top, 6)
            ForEach(items) { issue in
                Button {
                    onJump(issue.plugID)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: issue.severity == .problem ? "exclamationmark.triangle.fill" : "info.circle")
                            .foregroundStyle(issue.severity == .problem ? Palette.warnStrong : Palette.amberInk)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(issue.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Palette.text)
                            Text(issue.detail)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.nameText)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Palette.nameText)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.chipFill))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
