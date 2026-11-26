//
//  PageSheetSizing.swift
//  Harness Builder
//
//  On iPad a sheet is a small floating window by default, which makes the long
//  plug editor scroll a lot. From iOS 18 a sheet can ask for the taller "page"
//  size. Earlier versions, and iPhone, are unchanged.
//

import SwiftUI

extension View {
    @ViewBuilder
    func pageSizedSheet() -> some View {
        if #available(iOS 18.0, *) {
            self.presentationSizing(.page)
        } else {
            self
        }
    }
}
