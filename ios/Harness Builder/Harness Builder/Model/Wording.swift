//
//  Wording.swift
//  Harness Builder
//
//  Small helpers so counts read naturally ("1 pin", "2 pins").
//

import Foundation

/// "1 pin" or "N pins".
func pinCountText(_ n: Int) -> String {
    n == 1 ? "1 pin" : "\(n) pins"
}
