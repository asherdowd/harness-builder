//
//  LinkPickerSheet.swift
//  Harness Builder
//
//  Pick the plug on another harness that a component plug links to.
//

import SwiftUI

struct LinkPickerSheet: View {
    let store: HarnessStore
    let plugID: String
    let onClose: () -> Void

    var body: some View {
        let ref = store.plug(id: plugID)
        let candidates = ref.map { store.linkCandidates(excludingHarness: $0.harness.id) } ?? []
        let grouped = Dictionary(grouping: candidates, by: { $0.harness.id })
        let order = store.harnesses.map(\.id).filter { grouped[$0] != nil }

        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Link to a plug")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Button("Cancel", action: onClose)
                        .font(.system(size: 14, weight: .semibold))
                        .tint(Palette.amberInk)
                }
                Text("Pick the plug on another harness that this one connects to. You can then jump between them.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.nameText)

                if candidates.isEmpty {
                    Text("There are no plugs on other harnesses yet. Add a harness with plugs first.")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.chipText)
                        .padding(.top, 8)
                }

                ForEach(order, id: \.self) { hid in
                    let group = grouped[hid] ?? []
                    Text((group.first?.harness.tabLabel ?? "").uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.nameText)
                        .padding(.top, 6)
                    ForEach(group) { target in
                        Button {
                            store.setLink(from: plugID, to: PlugLink(hid: target.harness.id, cid: target.connector.id))
                            onClose()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(target.connector.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Palette.text)
                                    Text("\(target.connector.pinCount) pins")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Palette.nameText)
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
            .padding(16)
        }
        .background(Palette.sheetBg)
    }
}
