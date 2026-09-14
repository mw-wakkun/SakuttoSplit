//
//  BoundedIntegerField.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// 数字のみ・桁数上限付きの汎用入力欄。計算は呼ばない
struct BoundedIntegerField<FocusValue: Hashable>: View {
    @Binding var text: String
    var placeholder: LocalizedStringKey = ""
    var maxDigits: Int = InputLimits.totalAmountMaxDigits
    var focusedField: FocusState<FocusValue?>.Binding
    var focusValue: FocusValue

    var body: some View {
        TextField(placeholder, text: sanitizedBinding)
            .keyboardType(.numberPad)
            .focused(focusedField, equals: focusValue)
    }

    private var sanitizedBinding: Binding<String> {
        Binding(
            get: { text },
            set: { text = InputLimits.sanitizedDigitText($0, maxDigits: maxDigits) }
        )
    }
}

#Preview {
    BoundedIntegerFieldPreview()
}

private struct BoundedIntegerFieldPreview: View {
    @State private var text = "35000"
    @FocusState private var focusedField: String?

    var body: some View {
        HStack {
            BoundedIntegerField(
                text: $text,
                placeholder: "total_amount.placeholder",
                focusedField: $focusedField,
                focusValue: "amount"
            )
            .font(.title2)
            Text("unit.yen")
        }
        .padding()
    }
}
