//
//  CountStepper.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// 人数などの整数を 範囲内で増減する汎用ステッパー。計算は呼ばない
struct CountStepper<FocusValue: Hashable>: View {
    @Binding var text: String
    var range: ClosedRange<Int> = InputLimits.groupCountRange
    var unitLabel: LocalizedStringKey = "unit.person"
    var focusedField: FocusState<FocusValue?>.Binding
    var focusValue: FocusValue

    var body: some View {
        HStack(spacing: 8) {
            let currentCount = Int(text) ?? 1

            Button(action: {
                if currentCount > range.lowerBound {
                    text = "\(currentCount - 1)"
                }
            }) {
                Image(systemName: "minus.circle.fill").font(.title3)
            }
            .buttonStyle(.borderless)
            .disabled(currentCount <= range.lowerBound)

            TextField("", text: sanitizedBinding)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 35)
                .focused(focusedField, equals: focusValue)

            Button(action: {
                if currentCount < range.upperBound {
                    text = "\(currentCount + 1)"
                }
            }) {
                Image(systemName: "plus.circle.fill").font(.title3)
            }
            .buttonStyle(.borderless)

            Text(unitLabel)
        }
    }

    private var sanitizedBinding: Binding<String> {
        Binding(
            get: { text },
            set: { text = InputLimits.sanitizedCountText($0) }
        )
    }
}

#Preview {
    CountStepperPreview()
}

private struct CountStepperPreview: View {
    @State private var text = "4"
    @FocusState private var focusedField: String?

    var body: some View {
        CountStepper(text: $text, focusedField: $focusedField, focusValue: "count")
            .padding()
    }
}
