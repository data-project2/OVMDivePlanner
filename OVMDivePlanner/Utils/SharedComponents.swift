// SharedComponents.swift
// Reusable SwiftUI helpers used across views

import SwiftUI

enum OVMTheme {
    static let accent = Color(red: 91 / 255, green: 206 / 255, blue: 250 / 255)
    static let background = Color(red: 18 / 255, green: 31 / 255, blue: 52 / 255)
    static let card = Color(red: 27 / 255, green: 43 / 255, blue: 69 / 255).opacity(0.9)
    static let border = Color(red: 48 / 255, green: 70 / 255, blue: 106 / 255)
    static let textPrimary = Color(red: 212 / 255, green: 220 / 255, blue: 232 / 255)
    static let textSecondary = Color(red: 158 / 255, green: 178 / 255, blue: 202 / 255)
    static let textTertiary = Color(red: 112 / 255, green: 132 / 255, blue: 160 / 255)
    static let danger = Color(red: 244 / 255, green: 91 / 255, blue: 105 / 255)
    static let warningBackground = Color(red: 42 / 255, green: 21 / 255, blue: 32 / 255)
    static let tableHover = Color(red: 31 / 255, green: 49 / 255, blue: 78 / 255)
}

extension View {
    func ovmFormBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(OVMTheme.background)
            .foregroundStyle(OVMTheme.textPrimary)
    }
}

/// A labelled slider showing value in a badge on the right.
struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline).foregroundStyle(OVMTheme.textPrimary)
                Spacer()
                Text(String(format: format, value))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(OVMTheme.accent)
                    .frame(minWidth: 70, alignment: .trailing)
            }
            Slider(value: $value, in: range, step: step)
                .tint(OVMTheme.accent)
        }
    }
}
