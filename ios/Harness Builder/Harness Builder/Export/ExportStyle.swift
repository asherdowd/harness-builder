//
//  ExportStyle.swift
//  Harness Builder
//
//  How an export looks: the dark sheet, or a print-friendly one with a
//  white page, light colors and plain white plug bodies (little ink).
//

import SwiftUI

enum ExportStyle: Hashable {
    case dark, print

    var scheme: ColorScheme { self == .dark ? .dark : .light }
}

extension EnvironmentValues {
    /// True while drawing the print-friendly export.
    @Entry var exportPrint: Bool = false
}

private struct ExportBackground: ViewModifier {
    @Environment(\.exportPrint) private var print

    func body(content: Content) -> some View {
        content.background(print ? Color.white : Palette.bg)
    }
}

extension View {
    /// The page background: dark for the dark export, white for print.
    func exportBackground() -> some View {
        modifier(ExportBackground())
    }

    /// Applies an export style: color scheme and the print flag.
    func exportStyle(_ style: ExportStyle) -> some View {
        self
            .environment(\.colorScheme, style.scheme)
            .environment(\.exportPrint, style == .print)
    }
}
