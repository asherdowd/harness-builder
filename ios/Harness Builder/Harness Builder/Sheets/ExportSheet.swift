//
//  ExportSheet.swift
//  Harness Builder
//
//  Export a harness (or all of them) as a PDF or PNG, with the wire table
//  if wanted, then share, save or print it from the iOS share sheet.
//

import SwiftUI

struct ExportSheet: View {
    let store: HarnessStore
    let onClose: () -> Void

    private enum Scope: Hashable {
        case this, all
    }

    @State private var scope: Scope = .this
    @State private var format: HarnessExporter.Format = .pdf
    @State private var includeTable = true
    @State private var printFriendly = false
    @State private var busy = false
    @State private var files: [URL] = []
    @State private var errorText: String?

    private var targets: [Harness] {
        scope == .this ? [store.active] : store.harnesses
    }

    private var formatNote: String {
        switch format {
        case .pdf: return "One PDF with a page for each harness, then its wire table. Stays sharp when printed or zoomed."
        case .png: return "One image for each harness, with the wire table underneath."
        case .csv: return "One spreadsheet file with a row for every wire: plug, pin, color, function, gauge, type and where it connects. Opens in Numbers, Excel and Google Sheets."
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Palette.nameText)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Export")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Button("Done", action: onClose)
                        .font(.system(size: 14, weight: .semibold))
                        .tint(Palette.amberInk)
                }

                caption("What to export")
                SegRow(options: [(Scope.this, "This harness"), (Scope.all, "All harnesses")], selection: $scope)

                caption("Format")
                SegRow(options: [(HarnessExporter.Format.pdf, "PDF"), (HarnessExporter.Format.png, "PNG"), (HarnessExporter.Format.csv, "CSV")], selection: $format)
                caption(formatNote)

                if format != .csv {
                    Toggle("Include the wire table", isOn: $includeTable)
                        .tint(Palette.amberInk)
                        .foregroundStyle(Palette.chipText)
                        .padding(.top, 4)
                    Toggle("Print-friendly (white page, light on ink)", isOn: $printFriendly)
                        .tint(Palette.amberInk)
                        .foregroundStyle(Palette.chipText)
                }

                Button {
                    create()
                } label: {
                    HStack {
                        if busy { ProgressView().tint(Palette.amberText) }
                        Text(busy ? "Creating…" : "Create")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(Palette.amberText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Palette.amber))
                }
                .buttonStyle(.plain)
                .disabled(busy)
                .padding(.top, 6)

                if !files.isEmpty {
                    ShareLink(items: files) {
                        Label(files.count == 1 ? "Share or print the file" : "Share \(files.count) files",
                              systemImage: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.chipFill))
                    }
                }

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.warnStrong)
                }
            }
            .padding(16)
        }
        .background(Palette.sheetBg)
        // Changing a choice means the file made earlier no longer matches.
        .onChange(of: scope) { _, _ in files = [] }
        .onChange(of: format) { _, _ in files = [] }
        .onChange(of: includeTable) { _, _ in files = [] }
        .onChange(of: printFriendly) { _, _ in files = [] }
    }

    private func create() {
        busy = true
        files = []
        errorText = nil
        let list = targets
        let all = store.harnesses
        let table = includeTable
        let fmt = format
        let style: ExportStyle = printFriendly ? .print : .dark
        Task {
            // Let "Creating…" show before the drawing work starts.
            try? await Task.sleep(nanoseconds: 80_000_000)
            do {
                files = try HarnessExporter.export(list, includeTable: table, format: fmt, allHarnesses: all, style: style)
            } catch {
                errorText = error.localizedDescription
            }
            busy = false
        }
    }
}
