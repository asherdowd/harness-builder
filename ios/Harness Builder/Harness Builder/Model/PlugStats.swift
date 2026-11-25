//
//  PlugStats.swift
//  Harness Builder
//
//  Used and spare pin counts for a plug.
//

import Foundation

extension Connector {
    /// Pins with a wire on them.
    var wiredCount: Int { flatPins.filter { $0.pin.populated }.count }

    /// Pins with no wire.
    var spareCount: Int { flatPins.filter { !$0.pin.populated }.count }
}
