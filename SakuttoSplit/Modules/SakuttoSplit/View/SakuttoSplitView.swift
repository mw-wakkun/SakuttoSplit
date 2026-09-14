//
//  SakuttoSplitView.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI
import UIKit

/// 割り勘計算画面。セクションの組み立てと Intent 転送だけを行う
struct SakuttoSplitView<Presenter: SakuttoSplitPresenterProtocol>: View {

    @ObservedObject var presenter: Presenter
    @ObservedObject var adsController: AdsController
    let bannerAdUnitID: String
    let isAdsSDKReady: Bool
    @FocusState private var focusedField: SakuttoSplitFocus?
    @State private var rootViewControllerBox = RootViewControllerBox()
    @State private var isRestoreConfirmPresented = false
    @State private var isSaveMemberSetPresented = false
    @State private var isRewardSlotPresented = false
    @State private var isSlotFullPresented = false
    @State private var memberSetNameDraft = ""
    @Environment(\.scenePhase) private var scenePhase

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
                        Button(saveMemberSetButtonTitle) {
                            saveMemberSetTapped()
                        }
                        .disabled(presenter.viewState.groups.isEmpty)
                        Button("set.load") {
                            focusedField = nil
                            presenter.didTapOpenMemberSetSheet()
                        }
                    }

                    Section("section.results") {
                        CalculationResultSection(
                            results: presenter.viewState.results,
                            difference: presenter.viewState.difference,
                            validationIssue: presenter.viewState.validationIssue,
                            collectionSeats: presenter.collectionState.seats,
                            unpaidShareText: presenter.unpaidShareText,
                            isUnpaidShareEnabled: presenter.isUnpaidShareEnabled,
                            onToggleCollectionSeat: { presenter.didTapToggleCollectionSeat(id: $0) },
                            onSettleComplete: settleComplete
                        )
                    }
                }
                .navigationTitle("app.title")
                .navigationBarTitleDisplayMode(.inline)
                .scrollDismissesKeyboard(.immediately)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        restoreToolbarItem
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        moreMenuToolbarItem
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        keyboardPrimaryAction
                        Button("action.done") { focusedField = nil }
                    }
                }
            }

            stickyShare
            adBannerSlot
        }
        .background {
            RootViewControllerProbe(box: rootViewControllerBox)
                .frame(width: 0, height: 0)
        }
        .onAppear {
            adsController.refreshAdFreeState()
            Task { @MainActor in
                focusTotalAmountIfNeeded()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                adsController.refreshAdFreeState()
            case .background:
                presenter.didEnterBackground()
            default:
                break
            }
        }
        .alert(
            "session.restore_confirm_title",
            isPresented: $isRestoreConfirmPresented
        ) {
            Button("session.restore") {
                presenter.didTapRestoreLastBill()
            }
            Button(role: .cancel) {}
        } message: {
            Text("session.restore_confirm_message")
        }
        .alert("set.save", isPresented: $isSaveMemberSetPresented) {
            TextField("set.name_placeholder", text: $memberSetNameDraft)
            Button("set.save") {
                presenter.didTapSaveMemberSet(name: memberSetNameDraft)
            }
            Button(role: .cancel) {}
        }
        .alert(
            "set.reward_title",
            isPresented: $isRewardSlotPresented
        ) {
            Button("set.reward_title") {
                presentExtraSlotRewarded()
            }
            Button(role: .cancel) {}
        } message: {
            Text("set.reward_message")
        }
        .alert(
            "set.slot_full_title",
            isPresented: $isSlotFullPresented
        ) {
            Button(role: .cancel) {}
        } message: {
            Text("set.slot_full_message")
        }
        .sheet(isPresented: memberSetSheetBinding) {
            MemberSetSheet(
                memberSets: presenter.sessionChrome.memberSets,
                onSelect: applyMemberSetTapped,
                onDelete: { presenter.didTapDeleteMemberSet(id: $0) },
                onClose: { presenter.didTapCloseMemberSetSheet() }
            )
        }
    }

    /// リセットしてから広告。成功時は総額へ戻す。Presenter は SDK を知らない
    private func settleComplete() {
        let canSettle = presenter.viewState.validationIssue == nil
        presenter.didTapSettleComplete()
        guard canSettle else {
            focusedField = nil
            return
        }
        Task { @MainActor in
            focusTotalAmountIfNeeded()
        }
        guard let rootViewController = rootViewControllerBox.rootViewController else {
            return
        }
        adsController.presentInterstitialIfEligible(from: rootViewController)
    }

    /// 総額が空かつ VoiceOver オフのときだけ総額へフォーカスする。復元・編成適用では呼ばない
    private func focusTotalAmountIfNeeded() {
        guard presenter.viewState.totalAmountText.isEmpty else { return }
        guard !UIAccessibility.isVoiceOverRunning else { return }
        focusedField = .totalAmount
    }

    @ViewBuilder
    private var restoreToolbarItem: some View {
        if presenter.sessionChrome.hasLastBill {
            Button("session.restore") {
                restoreLastBillTapped()
            }
        }
    }

    private func restoreLastBillTapped() {
        focusedField = nil
        if presenter.needsRestoreConfirmation {
            isRestoreConfirmPresented = true
        } else {
            presenter.didTapRestoreLastBill()
        }
    }

    private func saveMemberSetTapped() {
        focusedField = nil
        guard !presenter.viewState.groups.isEmpty else { return }
        if presenter.sessionChrome.hasEmptyMemberSetSlot {
            presentSaveNamePrompt()
        } else if presenter.sessionChrome.canUnlockMemberSetSlot {
            isRewardSlotPresented = true
        } else {
            isSlotFullPresented = true
        }
    }

    private func presentSaveNamePrompt() {
        memberSetNameDraft = String(
            localized: "set.default_name \(presenter.sessionChrome.memberSets.count + 1)"
        )
        isSaveMemberSetPresented = true
    }

    private func presentExtraSlotRewarded() {
        guard let rootViewController = rootViewControllerBox.rootViewController else {
            return
        }
        adsController.presentRewarded(
            from: rootViewController,
            purpose: .extraMemberSetSlot
        ) {
            presenter.didUnlockMemberSetSlot()
            guard presenter.sessionChrome.hasEmptyMemberSetSlot else { return }
            presentSaveNamePrompt()
        }
    }

    private var saveMemberSetButtonTitle: LocalizedStringKey {
        if !presenter.sessionChrome.hasEmptyMemberSetSlot,
           !presenter.sessionChrome.canUnlockMemberSetSlot {
            return "set.slot_full_title"
        }
        return "set.save"
    }

    private func applyMemberSetTapped(id: UUID) {
        focusedField = nil
        presenter.didTapCloseMemberSetSheet()
        presenter.didTapApplyMemberSet(id: id)
    }

    private var memberSetSheetBinding: Binding<Bool> {
        Binding(
            get: { presenter.sessionChrome.isMemberSetSheetPresented },
            set: { presented in
                if presented {
                    presenter.didTapOpenMemberSetSheet()
                } else {
                    presenter.didTapCloseMemberSetSheet()
                }
            }
        )
    }

    private var moreMenuToolbarItem: some View {
        Menu {
            Section {
                if adsController.isAdFree {
                    Text("ads.off_remaining \(AdFreeRemaining.hours(remaining: adsController.adFreeRemaining))")
                } else {
                    Button("ads.hide_for_today", action: hideAdsForToday)
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("menu.more")
    }

    @ViewBuilder
    private var keyboardPrimaryAction: some View {
        if presenter.viewState.isShareEnabled {
            ShareLink(item: presenter.viewState.shareText) {
                Label("share.button", systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
            }
        } else {
            Button("action.next") {
                focusedField = focusedField?.next(in: presenter.viewState.groups)
            }
        }
    }

    private func hideAdsForToday() {
        guard let rootViewController = rootViewControllerBox.rootViewController else {
            return
        }
        adsController.didTapHideAdsForToday(from: rootViewController)
    }
}

// MARK: - Ad Banner

private extension SakuttoSplitView {

    @ViewBuilder
    var stickyShare: some View {
        if focusedField == nil {
            ShareResultButton(
                shareText: presenter.viewState.shareText,
                isEnabled: presenter.viewState.isShareEnabled
            )
        }
    }

    var adBannerSlot: some View {
        Group {
            if adsController.rewardUnavailable {
                Text("ads.reward_unavailable")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else if AdBannerSlot.showsLoadedBanner(
                isAdsSDKReady: isAdsSDKReady,
                isFocused: focusedField != nil,
                isAdFree: adsController.isAdFree
            ) {
                AdBannerView(adUnitID: bannerAdUnitID)
                    .equatable()
            }
        }
        .frame(height: bannerSlotHeight)
        .clipped()
    }

    private var bannerSlotHeight: CGFloat {
        if adsController.rewardUnavailable {
            return AdBannerSlot.expandedHeight
        }
        return AdBannerSlot.height(isFocused: focusedField != nil, isAdFree: adsController.isAdFree)
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
