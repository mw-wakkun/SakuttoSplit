//
//  GroupRowView.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// グループ 1 行。名前と人数は常時。支払いモードは折りたたみ。削除は親の swipe
struct GroupRowView: View {
    let group: AttendeeGroupDraft
    var focusedField: FocusState<SakuttoSplitFocus?>.Binding
    var onNameChange: (String) -> Void
    var onCountChange: (String) -> Void
    var onModeChange: (PaymentMode) -> Void
    var onFixedAmountChange: (String) -> Void
    var onRatioChange: (String) -> Void
    var onPaymentExpandedChange: (Bool) -> Void = { _ in }

    @State private var isPaymentExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("group.name_placeholder", text: nameBinding)
                    .focused(focusedField, equals: .groupName(group.id))

                CountStepper(
                    text: countBinding,
                    focusedField: focusedField,
                    focusValue: .groupCount(group.id)
                )
            }

            if isPaymentExpanded {
                expandedPaymentControls
            } else {
                collapsedPaymentCaption
            }
        }
        .padding(.vertical, 4)
    }

    private var collapsedPaymentCaption: some View {
        HStack(spacing: 4) {
            Text(group.mode == .fixed ? "payment_mode.fixed" : "payment_mode.ratio")
            if group.mode == .fixed {
                Text(YenFormatting.grouped(fromDigitText: group.fixedAmountText))
                Text("unit.yen")
            } else {
                Text(group.ratioText)
                Text("unit.times")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            isPaymentExpanded = true
            onPaymentExpandedChange(true)
        }
    }

    private var expandedPaymentControls: some View {
        HStack {
            Picker("group.mode", selection: modeBinding) {
                Text("payment_mode.ratio").tag(PaymentMode.ratio)
                Text("payment_mode.fixed").tag(PaymentMode.fixed)
            }
            .pickerStyle(.segmented)

            detailInputField
        }
    }

    @ViewBuilder
    private var detailInputField: some View {
        HStack {
            if group.mode == .fixed {
                BoundedIntegerField(
                    text: fixedAmountBinding,
                    placeholder: "group.fixed_amount_placeholder",
                    maxDigits: InputLimits.totalAmountMaxDigits,
                    focusedField: focusedField,
                    focusValue: .fixedAmount(group.id)
                )
                Text("unit.yen")
            } else {
                TextField("group.ratio_placeholder", text: ratioBinding)
                    .keyboardType(.decimalPad)
                    .focused(focusedField, equals: .ratio(group.id))
                Text("unit.times")
            }
        }
    }

    private var nameBinding: Binding<String> {
        Binding(get: { group.name }, set: onNameChange)
    }

    private var countBinding: Binding<String> {
        Binding(get: { group.countText }, set: onCountChange)
    }

    private var modeBinding: Binding<PaymentMode> {
        Binding(get: { group.mode }, set: onModeChange)
    }

    private var fixedAmountBinding: Binding<String> {
        Binding(get: { group.fixedAmountText }, set: onFixedAmountChange)
    }

    private var ratioBinding: Binding<String> {
        Binding(
            get: { group.ratioText },
            set: { onRatioChange(InputLimits.sanitizedRatioText($0)) }
        )
    }
}

/// Binding / クロージャは Equatable ではないため、宣言側では合成せず `group` だけ比較する
extension GroupRowView: Equatable {
    static func == (lhs: GroupRowView, rhs: GroupRowView) -> Bool {
        lhs.group == rhs.group
    }
}

#Preview("folded") {
    GroupRowViewPreview()
}

private struct GroupRowViewPreview: View {
    @State private var group = AttendeeGroupDraft(
        name: "部長",
        countText: "1",
        mode: .fixed,
        fixedAmountText: "10000"
    )
    @FocusState private var focusedField: SakuttoSplitFocus?

    var body: some View {
        Form {
            GroupRowView(
                group: group,
                focusedField: $focusedField,
                onNameChange: { group.name = $0 },
                onCountChange: { group.countText = $0 },
                onModeChange: { group.mode = $0 },
                onFixedAmountChange: { group.fixedAmountText = $0 },
                onRatioChange: { group.ratioText = $0 }
            )
            .equatable()
        }
    }
}
