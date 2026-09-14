//
//  SakuttoSplitView.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// 割り勘計算画面。セクションの組み立てと Intent 転送だけを行う
struct SakuttoSplitView: View {

    @ObservedObject var presenter: SakuttoSplitPresenter
    let bannerAdUnitID: String
    @FocusState private var focusedField: SakuttoSplitFocus?

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                Form {
                    Section("section.billing") {
                        TotalAmountSection(text: totalAmountBinding, focusedField: $focusedField)
                        RoundingUnitPicker(selection: roundingUnitBinding)
                    }

                    Section("section.groups") {
                        GroupListSection(
                            groups: presenter.viewState.groups,
                            nameBinding: nameBinding,
                            countBinding: countBinding,
                            modeBinding: paymentModeBinding,
                            fixedAmountBinding: fixedAmountBinding,
                            ratioBinding: ratioBinding,
                            focusedField: $focusedField,
                            onAdd: { presenter.didTapAddGroup() },
                            onRemove: { presenter.didTapRemoveGroup(id: $0) }
                        )
                    }

                    Section("section.results") {
                        CalculationResultSection(
                            results: presenter.viewState.results,
                            difference: presenter.viewState.difference,
                            shareText: presenter.shareText()
                        )
                    }
                }
                .navigationTitle("app.title")
                .navigationBarTitleDisplayMode(.inline)
                .scrollDismissesKeyboard(.immediately)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("action.done") { focusedField = nil }
                    }
                }
            }

            AdBannerView(adUnitID: bannerAdUnitID)
                .frame(height: 50)
        }
    }
}

// MARK: - Intent Bindings

private extension SakuttoSplitView {

    var totalAmountBinding: Binding<String> {
        Binding(
            get: { presenter.viewState.totalAmountText },
            set: { presenter.didChangeTotalAmount($0) }
        )
    }

    var roundingUnitBinding: Binding<RoundingUnit> {
        Binding(
            get: { presenter.viewState.roundingUnit },
            set: { presenter.didChangeRoundingUnit($0) }
        )
    }

    func nameBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { presenter.viewState.groups.first(where: { $0.id == id })?.name ?? "" },
            set: { presenter.didChangeGroupName(id: id, name: $0) }
        )
    }

    func countBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { presenter.viewState.groups.first(where: { $0.id == id })?.countText ?? "" },
            set: { presenter.didChangeGroupCount(id: id, countText: $0) }
        )
    }

    func paymentModeBinding(for id: UUID) -> Binding<PaymentMode> {
        Binding(
            get: { presenter.viewState.groups.first(where: { $0.id == id })?.mode ?? .ratio },
            set: { presenter.didChangePaymentMode(id: id, mode: $0) }
        )
    }

    func fixedAmountBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { presenter.viewState.groups.first(where: { $0.id == id })?.fixedAmountText ?? "" },
            set: { presenter.didChangeFixedAmount(id: id, text: $0) }
        )
    }

    func ratioBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { presenter.viewState.groups.first(where: { $0.id == id })?.ratioText ?? "" },
            set: { presenter.didChangeRatio(id: id, text: $0) }
        )
    }
}
