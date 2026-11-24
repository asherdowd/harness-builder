//
//  PinEditor.swift
//  Harness Builder
//
//  The controls for one pin: wire or empty, color, stripe, shade, function,
//  wire type, gauge, and how sure the user is.
//

import SwiftUI

/// A row of choices where one is selected.
struct SegRow<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { item in
                let on = item.element.0 == selection
                Button {
                    selection = item.element.0
                } label: {
                    Text(item.element.1)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(on ? Palette.amberText : Color(hex: 0xaeb4bd))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 8).fill(on ? Palette.amber : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 11).fill(Color(hex: 0x1d2128)))
    }
}

/// One pin elsewhere that the pin being edited is connected to.
struct PinConnection: Identifiable {
    var id: String
    var title: String   // "Fuel pump plug · pin 2"
    var sub: String     // the harness it is on
}

struct PinEditor: View {
    @Binding var pin: Pin
    var connections: [PinConnection] = []
    var onConnect: () -> Void = {}
    var onDisconnect: () -> Void = {}

    private var parts: ColorParts { ColorParts(code: pin.color) }

    private func setParts(_ change: (inout ColorParts) -> Void) {
        var p = parts
        change(&p)
        pin.color = p.code.isEmpty ? nil : p.code
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
    private let gaugeColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Palette.nameText)
            .padding(.top, 6)
    }

    private func colorButton(code: String, name: String, selected: Bool, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ColorSwatch(code: code, width: 30, height: 30)
                Text(name).font(.system(size: 10.5)).foregroundStyle(Color(hex: 0x9aa2ad))
            }
            .padding(4)
            .frame(maxWidth: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Palette.amber : Color.clear, lineWidth: 2))
            .opacity(disabled ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SegRow(options: [(true, "Has a wire"), (false, "Empty")], selection: $pin.populated)

            if pin.populated {
                caption("Main color")
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(wireTokens, id: \.code) { t in
                        colorButton(code: t.code, name: t.name, selected: parts.main == t.code) {
                            setParts { $0.main = t.code }
                        }
                    }
                }

                caption("Stripe (optional)")
                LazyVGrid(columns: columns, spacing: 6) {
                    Button {
                        setParts { $0.stripe = "" }
                    } label: {
                        VStack(spacing: 3) {
                            ColorSwatch(code: nil, width: 30, height: 30)
                            Text("None").font(.system(size: 10.5)).foregroundStyle(Color(hex: 0x9aa2ad))
                        }
                        .padding(4)
                        .frame(maxWidth: .infinity)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(parts.stripe.isEmpty ? Palette.amber : Color.clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    ForEach(wireTokens.filter { $0.code != parts.main }, id: \.code) { t in
                        colorButton(code: t.code, name: t.name, selected: parts.stripe == t.code, disabled: parts.main.isEmpty) {
                            setParts { $0.stripe = t.code }
                        }
                    }
                }

                SegRow(options: [(false, "Normal"), (true, "Light shade")],
                       selection: Binding(get: { parts.light }, set: { v in setParts { $0.light = v } }))

                caption("What does this wire do?")
                TextField("e.g. Injector 1 signal",
                          text: Binding(get: { pin.guess ?? "" }, set: { pin.guess = $0.isEmpty ? nil : $0 }))
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Color(hex: 0x1d2128)))
                    .foregroundStyle(.white)

                caption("Connects to (optional)")
                connectsTo

                caption("Wire type (optional)")
                SegRow(options: [(nil, "Not set"), ("power", "Hot"), ("signal", "Signal"), ("ground", "Ground")] as [(String?, String)],
                       selection: $pin.role)

                caption("Wire gauge, AWG (optional)")
                LazyVGrid(columns: gaugeColumns, spacing: 8) {
                    gaugeButton(label: "Not sure", value: nil)
                    ForEach(gaugeChoices, id: \.self) { g in
                        gaugeButton(label: "\(g)", value: g)
                    }
                }

                caption("How sure are you?")
                SegRow(options: [("High", "Sure"), ("Med", "Probably"), ("Low", "Guess")] as [(String?, String)],
                       selection: $pin.confidence)
            }
        }
    }

    /// Where this wire continues on other plugs, with buttons to add or clear connections.
    private var connectsTo: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(connections) { c in
                HStack(spacing: 10) {
                    Image(systemName: "link").foregroundStyle(Palette.amber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(c.sub)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.nameText)
                    }
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 11).fill(Color(hex: 0x1d2128)))
            }
            HStack(spacing: 8) {
                Button(connections.isEmpty ? "Connect to a pin" : "Connect to another pin", action: onConnect)
                    .buttonStyle(.bordered)
                    .tint(Palette.amber)
                if pin.netId != nil {
                    Button("Clear", role: .destructive, action: onDisconnect)
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func gaugeButton(label: String, value: Int?) -> some View {
        let on = pin.gauge == value
        return Button {
            pin.gauge = value
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.chipText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0x1d2128)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? Palette.amber : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}
