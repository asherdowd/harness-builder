//
//  RoleBadge.swift
//  Harness Builder
//
//  Wire roles (hot, signal, ground) and their symbols. Roles are set by hand.
//

import SwiftUI

enum WireRole: String, CaseIterable {
    case power, signal, ground

    var label: String {
        switch self {
        case .power: return "Hot (power)"
        case .signal: return "Signal"
        case .ground: return "Ground"
        }
    }

    var color: Color {
        switch self {
        case .power: return Color(hex: 0xef6a5b)
        case .signal: return Color(hex: 0x5cb0ee)
        case .ground: return Color(hex: 0xaab3be)
        }
    }
}

/// The symbol: "+" for hot, a wave for signal, the ground symbol for ground.
/// Drawn on a 12-unit grid centered in the rect.
struct RoleGlyph: Shape {
    let role: WireRole

    func path(in rect: CGRect) -> Path {
        let s = rect.width / 12
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.midX + x * s, y: rect.midY + y * s)
        }
        var p = Path()
        switch role {
        case .power:
            p.move(to: pt(-3.5, 0)); p.addLine(to: pt(3.5, 0))
            p.move(to: pt(0, -3.5)); p.addLine(to: pt(0, 3.5))
        case .signal:
            p.move(to: pt(-4, 0))
            p.addQuadCurve(to: pt(0, 0), control: pt(-2, -4.5))
            p.addQuadCurve(to: pt(4, 0), control: pt(2, 4.5))
        case .ground:
            p.move(to: pt(0, -4)); p.addLine(to: pt(0, 0))
            p.move(to: pt(-3.8, 0)); p.addLine(to: pt(3.8, 0))
            p.move(to: pt(-2.4, 2.2)); p.addLine(to: pt(2.4, 2.2))
            p.move(to: pt(-1, 4.2)); p.addLine(to: pt(1, 4.2))
        }
        return p
    }
}

/// A small round badge holding the symbol.
struct RoleBadge: View {
    let role: WireRole
    var size: CGFloat = 12

    var body: some View {
        ZStack {
            Circle().fill(Palette.bg)
            Circle().stroke(role.color, lineWidth: 0.9)
            RoleGlyph(role: role)
                .stroke(role.color, style: StrokeStyle(lineWidth: 1.5 * size / 13, lineCap: .round, lineJoin: .round))
                .padding(size * 0.12)
        }
        .frame(width: size, height: size)
    }
}
