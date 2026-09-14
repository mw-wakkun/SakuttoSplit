//
//  GroupRowView.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

struct GroupRowView: View {
    let groupID: UUID
    @Binding var name: String
    @Binding var countText: String
    @Binding var mode: PaymentMode
    @Binding var fixedAmountText: String
    @Binding var ratioText: String
    var focusedField: FocusState<SakuttoSplitFocus?>.Binding
    var onRemove: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("group.name_placeholder", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused(focusedField, equals: .groupName(groupID))

                CountStepper(
                    text: $countText,
                    focusedField: focusedField,
                    focusValue: .groupCount(groupID)
                )

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash").foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }

            HStack {
                Picker("group.mode", selection: $mode) {
                    Text("payment_mode.ratio").tag(PaymentMode.ratio)
                    Text("payment_mode.fixed").tag(PaymentMode.fixed)
                }
                .pickerStyle(.segmented)

                detailInputField
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var detailInputField: some View {
        HStack {
            if mode == .fixed {
                BoundedIntegerField(
                    text: $fixedAmountText,
                    placeholder: "group.fixed_amount_placeholder",
                    maxDigits: InputLimits.totalAmountMaxDigits,
                    focusedField: focusedField,
                    focusValue: .fixedAmount(groupID)
                )
                .textFieldStyle(.roundedBorder)
                Text("unit.yen")
            } else {
                TextField("group.ratio_placeholder", text: ratioBinding)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused(focusedField, equals: .ratio(groupID))
                Text("unit.times")
            }
        }
    }

    private var ratioBinding: Binding<String> {
        Binding(
            get: { ratioText },
            set: { ratioText = InputLimits.sanitizedRatioText($0) }
        )
    }
}

#Preview {
    GroupRowViewPreview()
}

private struct GroupRowViewPreview: View {
    @State private var name = "部長"
    @State private var countText = "1"
    @State private var mode = PaymentMode.fixed
    @State private var fixedAmountText = "10000"
    @State private var ratioText = "1.0"
    @FocusState private var focusedField: SakuttoSplitFocus?

    var body: some View {
        Form {
            GroupRowView(
                groupID: UUID(),
                name: $name,
                countText: $countText,
                mode: $mode,
                fixedAmountText: $fixedAmountText,
                ratioText: $ratioText,
                focusedField: $focusedField,
                onRemove: {}
            )
        }
    }
}
