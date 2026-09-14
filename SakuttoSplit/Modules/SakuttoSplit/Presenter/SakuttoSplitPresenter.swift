//
//  SakuttoSplitPresenter.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Combine
import Foundation

/// View の状態管理と、Interactor への計算依頼を行うプレゼンター
@MainActor
final class SakuttoSplitPresenter: SakuttoSplitPresenterProtocol {

    @Published private(set) var viewState: SakuttoSplitViewState
    @Published private(set) var sessionChrome = SakuttoSplitSessionChrome()
    @Published private(set) var collectionState = CollectionState.empty

    private let interactor: SakuttoSplitInteractorProtocol
    private let sessionStore: any BillSessionStoring

    var unpaidShareText: String {
        ShareTextBuilder.buildUnpaid(
            totalAmountText: viewState.totalAmountText,
            unpaidSeats: collectionState.unpaidSeats
        )
    }

    var isUnpaidShareEnabled: Bool {
        viewState.isShareEnabled && !collectionState.unpaidSeats.isEmpty
    }

    var needsRestoreConfirmation: Bool {
        guard let lastBill = sessionStore.lastBill else { return false }
        if Self.matchesInitialInput(viewState) { return false }
        return makeSnapshot() != lastBill
    }

    var needsMemberSetApplyConfirmation: Bool {
        viewState.groups.map(Self.inputFingerprint)
            != SakuttoSplitViewState.initial.groups.map(Self.inputFingerprint)
    }

    convenience init(interactor: SakuttoSplitInteractorProtocol) {
        self.init(
            interactor: interactor,
            initialState: .initial,
            sessionStore: BillSessionStore()
        )
    }

    convenience init(
        interactor: SakuttoSplitInteractorProtocol,
        sessionStore: any BillSessionStoring
    ) {
        self.init(interactor: interactor, initialState: .initial, sessionStore: sessionStore)
    }

    init(
        interactor: SakuttoSplitInteractorProtocol,
        initialState: SakuttoSplitViewState,
        sessionStore: any BillSessionStoring
    ) {
        self.interactor = interactor
        self.sessionStore = sessionStore
        var state = initialState
        Self.applyCalculation(to: &state, interactor: interactor)
        self.viewState = state
        self.sessionChrome = makeSessionChrome(isMemberSetSheetPresented: false)
        reconcileCollection()
    }

    func didChangeTotalAmount(_ text: String) {
        applyUpdate { $0.totalAmountText = InputLimits.sanitizedTotalAmountText(text) }
    }

    func didChangeRoundingUnit(_ unit: RoundingUnit) {
        applyUpdate { $0.roundingUnit = unit }
    }

    func didChangeGroupName(id: UUID, name: String) {
        applyUpdate { state in
            guard let index = state.groups.firstIndex(where: { $0.id == id }) else { return }
            state.groups[index].name = name
        }
    }

    func didChangeGroupCount(id: UUID, countText: String) {
        applyUpdate { state in
            guard let index = state.groups.firstIndex(where: { $0.id == id }) else { return }
            state.groups[index].countText = InputLimits.sanitizedCountText(countText)
        }
    }

    func didChangePaymentMode(id: UUID, mode: PaymentMode) {
        applyUpdate { state in
            guard let index = state.groups.firstIndex(where: { $0.id == id }) else { return }
            state.groups[index].mode = mode
        }
    }

    func didChangeFixedAmount(id: UUID, text: String) {
        applyUpdate { state in
            guard let index = state.groups.firstIndex(where: { $0.id == id }) else { return }
            state.groups[index].fixedAmountText = InputLimits.sanitizedFixedAmountText(text)
        }
    }

    func didChangeRatio(id: UUID, text: String) {
        applyUpdate { state in
            guard let index = state.groups.firstIndex(where: { $0.id == id }) else { return }
            state.groups[index].ratioText = InputLimits.sanitizedRatioText(text)
        }
    }

    func didTapAddGroup() {
        applyUpdate { state in
            let newGroupName = String(localized: "group.new_name \(state.groups.count + 1)")
            state.groups.append(
                AttendeeGroupDraft(name: newGroupName, countText: "1", mode: .ratio, ratioText: "1.0")
            )
        }
    }

    func didTapRemoveGroup(id: UUID) {
        applyUpdate { state in
            state.groups.removeAll { $0.id == id }
        }
    }

    /// 精算完了。妥当なら直前の入力を保存してから起動時と同じ状態へ戻す。広告は知らない
    func didTapSettleComplete() {
        guard viewState.validationIssue == nil else { return }
        saveLastBillIfValid()
        applyUpdate { $0 = .initial }
    }

    /// バックグラウンド遷移。妥当な入力のときだけ前回会計を上書きする
    func didEnterBackground() {
        saveLastBillIfValid()
    }

    /// 前回会計を入力へ流し込み、計算は 1 回。済はスナップショットから載せ直す
    func didTapRestoreLastBill() {
        guard let snapshot = sessionStore.lastBill else { return }
        applyUpdate { state in
            state.totalAmountText = snapshot.totalAmountText
            state.roundingUnit = snapshot.roundingUnit
            state.groups = snapshot.groups
        }
        reconcileCollection(paidSeatKeys: Set(snapshot.paidSeatKeys))
    }

    /// その席の済/未済だけ反転する。applyUpdate は呼ばない
    func didTapToggleCollectionSeat(id: CollectionSeatID) {
        var next = collectionState
        guard let index = next.seats.firstIndex(where: { $0.id == id }) else { return }
        next.seats[index].isPaid.toggle()
        collectionState = next
    }

    /// 空き枠があるときだけ編成を保存する。総額は持たない。計算は走らせない
    func didTapSaveMemberSet(name: String) {
        guard !viewState.groups.isEmpty else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty
            ? String(localized: "set.default_name \(sessionStore.memberSets.count + 1)")
            : trimmed
        let memberSet = MemberSet(
            name: resolvedName,
            roundingUnit: viewState.roundingUnit,
            groups: viewState.groups
        )
        guard sessionStore.saveMemberSet(memberSet) else { return }
        refreshSessionChrome()
    }

    func didTapOpenMemberSetSheet() {
        setMemberSetSheetPresented(true)
    }

    func didTapCloseMemberSetSheet() {
        setMemberSetSheetPresented(false)
    }

    /// 総額は維持し、端数とグループをセットで置き換える。席は作り直し（すべて未払い）
    func didTapApplyMemberSet(id: UUID) {
        guard let memberSet = sessionStore.memberSets.first(where: { $0.id == id }) else { return }
        applyUpdate { state in
            state.roundingUnit = memberSet.roundingUnit
            state.groups = memberSet.groups
        }
        reconcileCollection(paidSeatKeys: [])
        setMemberSetSheetPresented(false)
    }

    func didTapDeleteMemberSet(id: UUID) {
        sessionStore.deleteMemberSet(id: id)
        refreshSessionChrome()
    }

    /// リワード完了時だけ枠を 1 つ増やす。既に上限なら何もしない
    func didUnlockMemberSetSlot() {
        guard sessionStore.unlockExtraSlot() else { return }
        refreshSessionChrome()
    }

    private func saveLastBillIfValid() {
        guard viewState.validationIssue == nil else { return }
        sessionStore.saveLastBill(makeSnapshot())
        refreshSessionChrome()
    }

    private func refreshSessionChrome() {
        let next = makeSessionChrome(isMemberSetSheetPresented: sessionChrome.isMemberSetSheetPresented)
        guard next != sessionChrome else { return }
        sessionChrome = next
    }

    private func setMemberSetSheetPresented(_ presented: Bool) {
        guard sessionChrome.isMemberSetSheetPresented != presented else { return }
        sessionChrome.isMemberSetSheetPresented = presented
    }

    private func makeSessionChrome(isMemberSetSheetPresented: Bool) -> SakuttoSplitSessionChrome {
        SakuttoSplitSessionChrome(
            hasLastBill: sessionStore.lastBill != nil,
            memberSets: sessionStore.memberSets,
            slotCount: sessionStore.slotCount,
            isMemberSetSheetPresented: isMemberSetSheetPresented
        )
    }

    private func makeSnapshot() -> BillSnapshot {
        BillSnapshot(
            totalAmountText: viewState.totalAmountText,
            roundingUnit: viewState.roundingUnit,
            groups: viewState.groups,
            paidSeatKeys: collectionState.paidSeatKeys
        )
    }

    /// 妥当なときだけ席を作る。済は席 ID で引き継ぎ、validation 中は空（非表示相当）
    private func reconcileCollection(paidSeatKeys: Set<String>? = nil) {
        let next: CollectionState
        if viewState.validationIssue == nil {
            next = CollectionState.reconcile(
                groups: viewState.groups,
                results: viewState.results,
                paidSeatKeys: paidSeatKeys ?? Set(collectionState.paidSeatKeys),
                expandMaxCount: InputLimits.collectionExpandMaxCount
            )
        } else {
            next = .empty
        }
        guard next != collectionState else { return }
        collectionState = next
    }

    private static func matchesInitialInput(_ state: SakuttoSplitViewState) -> Bool {
        let initial = SakuttoSplitViewState.initial
        return state.totalAmountText == initial.totalAmountText
            && state.roundingUnit == initial.roundingUnit
            && state.groups.map(inputFingerprint) == initial.groups.map(inputFingerprint)
    }

    private static func inputFingerprint(_ group: AttendeeGroupDraft) -> [String] {
        [group.name, group.countText, "\(group.mode)", group.fixedAmountText, group.ratioText]
    }

    /// 入力が変わったときだけ 1 回計算し、viewState を 1 回だけ書き換える
    private func applyUpdate(_ update: (inout SakuttoSplitViewState) -> Void) {
        var next = viewState
        update(&next)
        guard next != viewState else { return }
        Self.applyCalculation(to: &next, interactor: interactor)
        viewState = next
        reconcileCollection()
    }

    private static func applyCalculation(
        to state: inout SakuttoSplitViewState,
        interactor: SakuttoSplitInteractorProtocol
    ) {
        let input = makeInput(from: state)
        let output = interactor.calculateBill(input)
        state.results = output.results
        state.difference = output.difference
        state.validationIssue = validationIssue(
            groupsEmpty: state.groups.isEmpty,
            totalAmountText: state.totalAmountText,
            input: input
        )
        state.shareText = ShareTextBuilder.build(from: state)
    }

    private static func makeInput(from state: SakuttoSplitViewState) -> BillCalculationInput {
        BillCalculationInput(
            totalAmount: Int(state.totalAmountText) ?? 0,
            roundingUnit: state.roundingUnit,
            groups: state.groups.map { $0.toDomain() }
        )
    }

    private static func validationIssue(
        groupsEmpty: Bool,
        totalAmountText: String,
        input: BillCalculationInput
    ) -> SakuttoSplitValidationIssue? {
        if groupsEmpty {
            return .noGroups
        }
        if totalAmountText.isEmpty {
            return .emptyTotalAmount
        }
        let fixedTotal = input.groups.reduce(into: 0) { sum, group in
            if group.mode == .fixed {
                sum += group.fixedAmount * group.count
            }
        }
        if fixedTotal > input.totalAmount {
            return .fixedAmountExceedsTotal
        }
        return nil
    }
}
