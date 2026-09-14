//
//  TotalAmountSection.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

struct TotalAmountSection: View {
    @Binding var text: String
    var focusedField: FocusState<SakuttoSplitFocus?>.Binding

    var body: some View {
        HStack {
            BoundedIntegerField(
                text: $text,
                placeholder: "total_amount.placeholder",
                maxDigits: InputLimits.totalAmountMaxDigits,
                focusedField: focusedField,
                focusValue: .totalAmount
            )
            .font(.title2)
            Text("unit.yen")
        }
    }
}

#Preview {
    TotalAmountSectionPreview()
}

private struct TotalAmountSectionPreview: View {
    @State private var text = "35000"
    @FocusState private var focusedField: SakuttoSplitFocus?

    var body: some View {
        Form {
            TotalAmountSection(text: $text, focusedField: $focusedField)
        }
    }
}
