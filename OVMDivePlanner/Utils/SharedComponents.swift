// SharedComponents.swift
// Reusable SwiftUI helpers used across views

import SwiftUI

enum OVMTheme {
    static let accent = Color(red: 91 / 255, green: 206 / 255, blue: 250 / 255)
    static let background = Color(red: 11 / 255, green: 22 / 255, blue: 40 / 255)
    static let card = Color(red: 18 / 255, green: 30 / 255, blue: 51 / 255).opacity(0.85)
    static let border = Color(red: 30 / 255, green: 48 / 255, blue: 80 / 255)
    static let textPrimary = Color(red: 212 / 255, green: 220 / 255, blue: 232 / 255)
    static let textSecondary = Color(red: 143 / 255, green: 164 / 255, blue: 190 / 255)
    static let textTertiary = Color(red: 90 / 255, green: 112 / 255, blue: 144 / 255)
    static let danger = Color(red: 244 / 255, green: 91 / 255, blue: 105 / 255)
    static let warningBackground = Color(red: 42 / 255, green: 21 / 255, blue: 32 / 255)
    static let tableHover = Color(red: 21 / 255, green: 37 / 255, blue: 62 / 255)
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
