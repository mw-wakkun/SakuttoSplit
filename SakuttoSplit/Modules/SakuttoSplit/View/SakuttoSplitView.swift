//
//  SakuttoSplitView.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// 割り勘計算画面。セクションの組み立てと Intent 転送だけを行う
struct SakuttoSplitView<Presenter: SakuttoSplitPresenterProtocol>: View {

    @ObservedObject var presenter: Presenter
    @ObservedObject var adsController: AdsController
    let bannerAdUnitID: String
    let isAdsSDKReady: Bool
    @FocusState private var focusedField: SakuttoSplitFocus?
    @State private var rootViewControllerBox = RootViewControllerBox()

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
                            focusedField: $focusedField,
                            onNameChange: { presenter.didChangeGroupName(id: $0, name: $1) },
                            onCountChange: { presenter.didChangeGroupCount(id: $0, countText: $1) },
                            onModeChange: { presenter.didChangePaymentMode(id: $0, mode: $1) },
                            onFixedAmountChange: { presenter.didChangeFixedAmount(id: $0, text: $1) },
                            onRatioChange: { presenter.didChangeRatio(id: $0, text: $1) },
                            onAdd: { presenter.didTapAddGroup() },
                            onRemove: { presenter.didTapRemoveGroup(id: $0) }
                        )
                    }

                    Section("section.results") {
                        CalculationResultSection(
                            results: presenter.viewState.results,
                            difference: presenter.viewState.difference,
                            shareText: presenter.viewState.shareText,
                            validationIssue: presenter.viewState.validationIssue,
                            onSettleComplete: settleComplete
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

            adBannerSlot
        }
        .background {
            RootViewControllerProbe(box: rootViewControllerBox)
                .frame(width: 0, height: 0)
        }
    }

    /// リセットしてから広告。Presenter は SDK を知らない
    private func settleComplete() {
        focusedField = nil
        let canSettle = presenter.viewState.validationIssue == nil
        presenter.didTapSettleComplete()
        guard canSettle, let rootViewController = rootViewControllerBox.rootViewController else {
            return
        }
        adsController.presentInterstitialIfEligible(from: rootViewController)
    }
}

// MARK: - Ad Banner

private extension SakuttoSplitView {

    var adBannerSlot: some View {
        Group {
            if AdBannerSlot.showsLoadedBanner(
                isAdsSDKReady: isAdsSDKReady,
                isFocused: focusedField != nil,
                isAdFree: adsController.isAdFree
            ) {
                AdBannerView(adUnitID: bannerAdUnitID)
                    .equatable()
            }
        }
        .frame(height: AdBannerSlot.height(isFocused: focusedField != nil, isAdFree: adsController.isAdFree))
        .clipped()
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
}
