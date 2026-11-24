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
    let linked: Bool
    let showRoles: Bool
    let canUp: Bool
    let canDown: Bool
    /// Scale that keeps the move buttons a steady size on screen at any zoom.
    let counterScale: CGFloat
    let onMove: (Int) -> Void
    let onTap: () -> Void

    private func moveButton(_ symbol: String, enabled: Bool, delta: Int) -> some View {
        Button {
            onMove(delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(enabled ? Palette.amberText : Palette.nameText)
                .frame(width: 34, height: 34)
                .background(Circle().fill(enabled ? Palette.amber : Palette.chipFill))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    var body: some View {
        let cx = shiftX + item.x
        let w = item.width
        let h = item.height
        ZStack {
            if selected || linked {
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? Palette.amber.opacity(0.10) : Color(hex: 0x6fb3c9, opacity: 0.10))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(selected ? Palette.amber : Color(hex: 0x6fb3c9),
                                style: StrokeStyle(lineWidth: selected ? 2.2 : 1.8, dash: selected ? [] : [5, 4])))
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

            if selected {
                VStack(spacing: 8) {
                    moveButton("chevron.up", enabled: canUp, delta: -1)
                    moveButton("chevron.down", enabled: canDown, delta: 1)
                }
                .scaleEffect(counterScale)
                .position(x: cx + item.side * (w / 2 + 9 + 17 * counterScale + 8), y: item.y + 20)
            }
        }
    }
}

// MARK: - the canvas

struct HarnessCanvasView: View {
    let harness: Harness
    let selectedID: String?
    let onSelect: (String?) -> Void
    /// Show the wire-type symbols on pins.
    var showRoles: Bool = false
    /// Plugs to outline as "connected to the selected wire".
    var linkedIDs: Set<String> = []
    /// Zooms to this plug whenever focusTick changes.
    var focusID: String? = nil
    var focusTick: Int = 0
    /// Moves a plug up (-1) or down (+1) along the trunk.
    var onMove: (String, Int) -> Void = { _, _ in }
    /// Changes whenever the parent wants the view fitted to the whole harness.
    var fitTick: Int = 0

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragBase: CGSize = .zero
    @State private var pinch: PinchBase?
    @State private var viewSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let layout = HarnessLayout(connectors: harness.connectors)
            Palette.bg
                .contentShape(Rectangle())
                .onTapGesture { onSelect(nil) }
                .overlay { gridLayer(color: Palette.grid) }
                .overlay(alignment: .topLeading) {
                    world(layout)
                        .frame(width: layout.worldWidth, height: layout.worldHeight, alignment: .topLeading)
                        .scaleEffect(scale, anchor: .topLeading)
                        .offset(offset)
                }
                .clipped()
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
                .onChange(of: fitTick) { _, _ in
                    fit(HarnessLayout(connectors: harness.connectors), in: geo.size, animated: true)
                }
                .onChange(of: harness.id) { _, _ in
                    fit(HarnessLayout(connectors: harness.connectors), in: geo.size, animated: false)
                }
                // After the harness change above, so a jump to another harness ends zoomed on the plug.
                .onChange(of: focusTick) { _, _ in
                    focus(HarnessLayout(connectors: harness.connectors), in: geo.size)
                }
        }
    }

    /// A faint grid that pans and zooms with the harness.
    private func gridLayer(color: Color) -> some View {
        let step = 28 * scale
        let shift = offset
        return Canvas { context, size in
            guard step >= 7 else { return }
            var path = Path()
            var x = shift.width.truncatingRemainder(dividingBy: step)
            if x < 0 { x += step }
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y = shift.height.truncatingRemainder(dividingBy: step)
            if y < 0 { y += step }
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(color), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }

    private func world(_ layout: HarnessLayout) -> some View {
        ZStack(alignment: .topLeading) {
            TrunkLayer(layout: layout).allowsHitTesting(false)
            LeadsLayer(layout: layout).allowsHitTesting(false)
            ForEach(Array(layout.items.enumerated()), id: \.element.id) { pair in
                PlugItemView(item: pair.element, shiftX: layout.shiftX, selected: pair.element.id == selectedID,
                             linked: linkedIDs.contains(pair.element.id),
                             showRoles: showRoles,
                             canUp: pair.offset > 0,
                             canDown: pair.offset < layout.items.count - 1,
                             counterScale: min(max(1 / max(scale, 0.01), 0.4), 2.5),
                             onMove: { delta in onMove(pair.element.id, delta) },
                             onTap: { onSelect(pair.element.id) })
            }
        }
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
                let newScale = min(max(base.scale * v.magnification, 0.15), 3)
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

    // MARK: focus

    /// Brings one plug into the top part of the view (the plug sheet covers the bottom).
    private func focus(_ layout: HarnessLayout, in size: CGSize) {
        guard let id = focusID, let item = layout.items.first(where: { $0.id == id }) else { return }
        let k = min(max(scale, 0.75), 3)
        let newOffset = CGSize(width: size.width / 2 - (layout.shiftX + item.x) * k,
                               height: size.height * 0.26 - item.y * k)
        withAnimation(.easeOut(duration: 0.38)) {
            scale = k
            offset = newOffset
        }
        dragBase = newOffset
    }

    // MARK: fit

    private func fit(_ layout: HarnessLayout, in size: CGSize, animated: Bool) {
        guard size.width > 0 else { return }
        let bw = layout.maxX - layout.minX + 56 + 96
        let k = min(max(min(1, size.width / bw), 0.15), 1)
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
