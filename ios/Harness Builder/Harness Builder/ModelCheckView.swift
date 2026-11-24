//
//  ModelCheckView.swift
//  Harness Builder
//
//  TEMPORARY screen for checking the data model, templates and saving.
//  It is not the app's UI and will be deleted once the real canvas exists.
//
//  Try: Try the example -> switch tabs -> Add a template (Component) -> link
//  its plug -> force-quit and reopen the app -> everything should still be there.
//

import SwiftUI

struct ModelCheckView: View {
    @State private var store = HarnessStore()

    var body: some View {
        NavigationStack {
            List {
                if let err = store.loadError {
                    Section("Problems") { Text(err).font(.caption).foregroundStyle(.red) }
                }

                Section("Harnesses (tap to open)") {
                    ForEach(store.harnesses) { h in
                        Button {
                            store.setActive(h.id)
                        } label: {
                            HStack {
                                Text((h.kind == .component ? "◇ " : "") + h.tabLabel)
                                Spacer()
                                Text("\(h.connectors.count) plugs").foregroundStyle(.secondary)
                                if h.id == store.state.activeID { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }

                Section("Plugs in \(store.active.title)") {
                    if store.active.connectors.isEmpty {
                        Text("Empty").foregroundStyle(.secondary)
                    }
                    ForEach(store.active.connectors) { c in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(c.title).font(.headline)
                            Text("\(c.pinCount) pins · \(c.shape)").font(.caption).foregroundStyle(.secondary)
                            if let target = store.linkTarget(of: c) {
                                Text("Linked to \(target.connector.title) on \(target.harness.title)")
                                    .font(.caption).foregroundStyle(.blue)
                            }
                            ForEach(store.linkedComponents(to: c.id)) { ref in
                                Text("Linked component: \(ref.harness.title)")
                                    .font(.caption).foregroundStyle(.blue)
                            }
                            if store.active.kind == .component {
                                Menu("Link to a plug…") {
                                    ForEach(store.linkCandidates(excludingHarness: store.active.id)) { ref in
                                        Button("\(ref.harness.title): \(ref.connector.title)") {
                                            store.setLink(from: c.id, to: PlugLink(hid: ref.harness.id, cid: ref.connector.id))
                                        }
                                    }
                                }
                                .buttonStyle(.borderless)
                                if c.link != nil {
                                    Button("Unlink", role: .destructive) { store.setLink(from: c.id, to: nil) }
                                        .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }

                Section("Actions") {
                    Button("Try the example") { store.loadExample() }
                    Menu("Add a template…") {
                        ForEach(store.templates) { t in
                            Button(t.label) { store.addTemplate(key: t.key) }.disabled(!store.canAdd(t))
                        }
                    }
                    Button("Create a harness") { store.createHarness() }
                    Button("Delete this harness", role: .destructive) { store.deleteHarness(id: store.active.id) }
                    Button("Reset to blank first open", role: .destructive) { store.resetAll() }
                }

                Section("Saved at") {
                    Text(store.fileURL.path).font(.caption2).textSelection(.enabled)
                    if let e = store.saveError { Text("Save failed: \(e)").font(.caption).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Model check")
        }
    }
}

#Preview {
    ModelCheckView()
}
