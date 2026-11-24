//
//  HarnessCanvasView.swift
//  Harness Builder
//
//  The harness canvas: a trunk with plugs branching off, pan and pinch zoom,
//  "Fit all", and tap-to-select.
//

import SwiftUI

private struct PinchBase {
    var scale: CGFloat
    var offset: CGSize
}

// MARK: - drawing layers (all in "world" coordinates, already shifted by shiftX)

private struct TrunkLayer: View {
    let layout: HarnessLayout

    var body: some View {
        let top: CGFloat = 30
        let bottom = layout.lastY
        let cx = layout.shiftX
        if layout.items.isEmpty {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Palette.trunkStroke, style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                .frame(width: 28, height: 190)
                .position(x: cx, y: top + 95)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Palette.trunkFill)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.trunkStroke, lineWidth: 2))
                    .frame(width: 28, height: bottom - top)
                    .position(x: cx, y: top + (bottom - top) / 2)
                ForEach([-5, 0, 5], id: \.self) { dx in
                    Path { p in
                        p.move(to: CGPoint(x: cx + CGFloat(dx), y: top + 6))
                        p.addLine(to: CGPoint(x: cx + CGFloat(dx), y: bottom - 6))
                    }
                    .stroke(Palette.trunkStrand, style: StrokeStyle(lineWidth: 1, dash: [1, 5]))
                }
            }
        }
    }
}

private struct LeadsLayer: View {
    let layout: HarnessLayout

    var body: some View {
        let sx = layout.shiftX
        ZStack {
            Path { p in
                for it in layout.items {
                    let edge = it.side * 14
                    let plugEdge = it.x - it.side * ((it.width - 14) / 2)
                    p.move(to: CGPoint(x: sx + edge, y: it.y))
                    p.addCurve(to: CGPoint(x: sx + plugEdge, y: it.y),
                               control1: CGPoint(x: sx + edge + it.side * 24, y: it.y),
                               control2: CGPoint(x: sx + plugEdge - it.side * 20, y: it.y))
                }
            }
            .stroke(Palette.leadStroke, lineWidth: 2)

            ForEach(layout.items) { it in
                Circle()
                    .fill(Palette.trunkStroke)
                    .frame(width: 5, height: 5)
                    .position(x: sx + it.side * 14, y: it.y)
            }
        }
    }
}

private struct PlugItemView: View {
    let item: PlacedPlug
    let shiftX: CGFloat
    let selected: Bool
    let showRoles: Bool
    let onTap: () -> Void

    var body: some View {
        let cx = shiftX + item.x
        let w = item.width
        let h = item.height
        ZStack {
            if selected {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Palette.amber.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.amber, lineWidth: 2.2))
                    .frame(width: w + 18, height: h + 58)
                    .position(x: cx, y: item.y + 20)
                    .allowsHitTesting(false)
            }

            PlugArt(model: item.art, showRoles: showRoles)
                .position(x: cx, y: item.y)

            Text(item.connector.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.idText)
                .lineLimit(1)
                .fixedSize()
                .position(x: cx, y: item.y + h / 2 + 17)
                .allowsHitTesting(false)

            Text("\(item.connector.pinCount) pins")
                .font(.system(size: 11))
                .foregroundStyle(Palette.nameText)
                .fixedSize()
                .position(x: cx, y: item.y + h / 2 + 32)
                .allowsHitTesting(false)

            Color.clear
                .frame(width: w + 24, height: h + 52)
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .position(x: cx, y: item.y + 14)
        }
    }
}

// MARK: - the canvas

struct HarnessCanvasView: View {
    let harness: Harness
    let selectedID: String?
    let onSelect: (String?) -> Void

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragBase: CGSize = .zero
    @State private var pinch: PinchBase?
    @State private var viewSize: CGSize = .zero
    @State private var showRoles = false

    var body: some View {
        GeometryReader { geo in
            let layout = HarnessLayout(connectors: harness.connectors)
            Palette.bg
                .contentShape(Rectangle())
                .onTapGesture { onSelect(nil) }
                .overlay(alignment: .topLeading) {
                    world(layout)
                        .frame(width: layout.worldWidth, height: layout.worldHeight, alignment: .topLeading)
                        .scaleEffect(scale, anchor: .topLeading)
                        .offset(offset)
                }
                .clipped()
                .overlay(alignment: .topTrailing) { fitButton(layout, geo.size) }
                .gesture(panGesture)
                .simultaneousGesture(zoomGesture)
                .onAppear {
                    viewSize = geo.size
                    fit(layout, in: geo.size, animated: false)
                }
                .onChange(of: geo.size) { _, newSize in
                    viewSize = newSize
                    fit(HarnessLayout(connectors: harness.connectors), in: newSize, animated: false)
                }
                .onChange(of: harness.id) { _, _ in
                    fit(HarnessLayout(connectors: harness.connectors), in: geo.size, animated: false)
                }
        }
    }

    private func world(_ layout: HarnessLayout) -> some View {
        ZStack(alignment: .topLeading) {
            TrunkLayer(layout: layout).allowsHitTesting(false)
            LeadsLayer(layout: layout).allowsHitTesting(false)
            ForEach(layout.items) { item in
                PlugItemView(item: item, shiftX: layout.shiftX, selected: item.id == selectedID, showRoles: showRoles) {
                    onSelect(item.id)
                }
            }
        }
    }

    private func fitButton(_ layout: HarnessLayout, _ size: CGSize) -> some View {
        HStack(spacing: 8) {
            Button {
                showRoles.toggle()
            } label: {
                Text("Roles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(showRoles ? Palette.amberText : Palette.chipText)
                    .padding(.horizontal, 13)
                    .frame(height: 32)
                    .background(Capsule().fill(showRoles ? Palette.amber : Color(hex: 0x282c34, opacity: 0.9)))
            }
            Button {
                fit(layout, in: size, animated: true)
            } label: {
                Text("Fit all")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.chipText)
                    .padding(.horizontal, 13)
                    .frame(height: 32)
                    .background(Capsule().fill(Color(hex: 0x282c34, opacity: 0.9)))
            }
        }
        .padding(.top, 8)
        .padding(.trailing, 12)
    }

    // MARK: gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                guard pinch == nil else { return }
                offset = CGSize(width: dragBase.width + v.translation.width,
                                height: dragBase.height + v.translation.height)
            }
            .onEnded { _ in
                dragBase = offset
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                if pinch == nil { pinch = PinchBase(scale: scale, offset: offset) }
                guard let base = pinch else { return }
                let newScale = min(max(base.scale * v.magnification, 0.25), 3)
                // Keep the point under the fingers where it was when the pinch started.
                let a = v.startLocation
                let wx = (a.x - base.offset.width) / base.scale
                let wy = (a.y - base.offset.height) / base.scale
                scale = newScale
                offset = CGSize(width: a.x - wx * newScale, height: a.y - wy * newScale)
            }
            .onEnded { _ in
                pinch = nil
                dragBase = offset
            }
    }

    // MARK: fit

    private func fit(_ layout: HarnessLayout, in size: CGSize, animated: Bool) {
        guard size.width > 0 else { return }
        let bw = layout.maxX - layout.minX + 56
        let k = min(max(min(1, size.width / bw), 0.3), 1)
        let cx = (layout.minX + layout.maxX) / 2 + layout.shiftX
        let newOffset = CGSize(width: size.width / 2 - cx * k, height: 14)
        if animated {
            withAnimation(.easeOut(duration: 0.38)) {
                scale = k
                offset = newOffset
            }
        } else {
            scale = k
            offset = newOffset
        }
        dragBase = newOffset
    }
}
