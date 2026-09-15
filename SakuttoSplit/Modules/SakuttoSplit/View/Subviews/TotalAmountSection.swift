//
//  TotalAmountSection.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// ヒーロー総額。正本は数字文字列のまま。非フォーカス時だけグループ化して見せる
struct TotalAmountSection: View {
    @Binding var text: String
    var focusedField: FocusState<SakuttoSplitFocus?>.Binding

    private var isFocused: Bool {
        focusedField.wrappedValue == .totalAmount
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            ZStack(alignment: .leading) {
                BoundedIntegerField(
                    text: $text,
                    placeholder: "total_amount.placeholder",
                    maxDigits: InputLimits.totalAmountMaxDigits,
                    focusedField: focusedField,
                    focusValue: .totalAmount
                )
                .opacity(isFocused ? 1 : 0)
                .allowsHitTesting(isFocused)
                .accessibilityHidden(!isFocused)

                if !isFocused {
                    Button {
                        focusedField.wrappedValue = .totalAmount
                    } label: {
                        unfocusedDisplay
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.largeTitle.monospacedDigit())
            .minimumScaleFactor(0.5)
            .lineLimit(1)

            Text("unit.yen")
        }
    }

    @ViewBuilder
    private var unfocusedDisplay: some View {
        if text.isEmpty {
            Text("total_amount.placeholder")
                .foregroundStyle(.secondary)
        } else {
            Text(YenFormatting.grouped(fromDigitText: text))
        }
    }
}

#Preview("empty") {
    TotalAmountSectionPreview(text: "")
}

#Preview("grouped") {
    TotalAmountSectionPreview(text: "35000")
}

private struct TotalAmountSectionPreview: View {
    @State var text: String
    @FocusState private var focusedField: SakuttoSplitFocus?

    var body: some View {
        Form {
            TotalAmountSection(text: $text, focusedField: $focusedField)
        }
    }
}
