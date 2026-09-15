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
    let reminderScheduler: any UnpaidReminderScheduling
    private var cachedUnpaidShareText = ""
    private var cachedIsUnpaidShareEnabled = false
    /// この会計でメインシェアを押したか。Disk には書かない。精算で落ちる
    private var hasPerformedMainShareThisBill = false

    var unpaidShareText: String { cachedUnpaidShareText }

    var isUnpaidShareEnabled: Bool { cachedIsUnpaidShareEnabled }

    var needsRestoreConfirmation: Bool {
        guard let lastBill = sessionStore.lastBill else { return false }
        if Self.matchesInitialInput(viewState) { return false }
        return makeSnapshot() != lastBill
    }

    var showsResumeCard: Bool {
        sessionChrome.lastBillPreview != nil && Self.matchesInitialInput(viewState)
    }

    var showsRestoreToolbar: Bool {
        sessionChrome.hasLastBill && !Self.matchesInitialInput(viewState)
    }

    var isInitialInput: Bool {
        Self.matchesInitialInput(viewState)
    }

    var showsMemberSetOffer: Bool {
        sessionStore.memberSets.isEmpty
            && sessionChrome.hasEmptyMemberSetSlot
            && hasPerformedMainShareThisBill
            && !sessionStore.memberSetOfferConsumed
            && !viewState.groups.isEmpty
            && viewState.validationIssue == nil
    }

    /// 編成適用前の groups + roundingUnit。通常の applyUpdate で捨てる
    private var memberSetUndo: MemberSetUndo?
    /// 履歴の「同じ編成で始める」の取り消し。総額も含む
    private var historyCompositionUndo: HistoryCompositionUndo?

    convenience init(interactor: SakuttoSplitInteractorProtocol) {
        self.init(
            interactor: interactor,
            initialState: .initial,
            sessionStore: BillSessionStore()
        )
    }

    convenience init(
        interactor: SakuttoSplitInteractorProtocol,
        sessionStore: any BillSessionStoring,
        reminderScheduler: any UnpaidReminderScheduling = NullUnpaidReminderScheduler()
    ) {
        self.init(
            interactor: interactor,
            initialState: .initial,
            sessionStore: sessionStore,
            reminderScheduler: reminderScheduler
        )
    }

    init(
        interactor: SakuttoSplitInteractorProtocol,
        initialState: SakuttoSplitViewState,
        sessionStore: any BillSessionStoring,
        reminderScheduler: any UnpaidReminderScheduling = NullUnpaidReminderScheduler()
    ) {
        self.interactor = interactor
        self.sessionStore = sessionStore
        self.reminderScheduler = reminderScheduler
        var state = initialState
        state.groups = Self.normalizingGroups(state.groups)
        Self.applyCalculation(to: &state, interactor: interactor)
        self.viewState = state
        self.sessionChrome = makeSessionChrome()
        reconcileCollection()
        refreshUnpaidShareCache()
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
            guard state.groups.count < InputLimits.groupMaxCount else { return }
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
        reminderScheduler.sync(unpaidCount: 0)
        hasPerformedMainShareThisBill = false
        applyUpdate { $0 = .initial }
    }

    /// バックグラウンド遷移。妥当な入力のときだけ前回会計を上書きする
    func didEnterBackground() {
        saveLastBillIfValid()
    }

    /// 前回会計を入力へ流し込み、計算は 1 回。済はスナップショットから載せ直す
    func didTapRestoreLastBill() {
        guard let snapshot = sessionStore.lastBill else { return }
        applyUpdate(paidSeatKeys: Set(snapshot.paidSeatKeys)) { state in
            state.totalAmountText = snapshot.totalAmountText
            state.roundingUnit = snapshot.roundingUnit
            state.groups = snapshot.groups
        }
    }

    /// その席の済/未済だけ反転する。applyUpdate は呼ばない
    func didTapToggleCollectionSeat(id: CollectionSeatID) {
        var next = collectionState
        guard let index = next.seats.firstIndex(where: { $0.id == id }) else { return }
        next.seats[index].isPaid.toggle()
        setCollectionState(next)
    }

    /// そのグループの席をすべて済にする。計算しない。すでに全員済なら何もしない
    func didTapMarkGroupCollectionPaid(groupID: UUID) {
        var next = collectionState
        let indices = next.seats.indices.filter { next.seats[$0].id.groupID == groupID }
        guard !indices.isEmpty else { return }
        guard indices.contains(where: { !next.seats[$0].isPaid }) else { return }
        for index in indices {
            next.seats[index].isPaid = true
        }
        setCollectionState(next)
    }

    /// 回収ボードの全席を済にする。計算しない。すでに全員済なら何もしない
    func didTapMarkAllCollectionPaid() {
        var next = collectionState
        guard next.seats.contains(where: { !$0.isPaid }) else { return }
        for index in next.seats.indices {
            next.seats[index].isPaid = true
        }
        setCollectionState(next)
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
        consumeMemberSetOfferIfNeeded()
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
        let undo = MemberSetUndo(groups: viewState.groups, roundingUnit: viewState.roundingUnit)
        applyUpdate(paidSeatKeys: []) { state in
            state.roundingUnit = memberSet.roundingUnit
            state.groups = memberSet.groups
        }
        setMemberSetSheetPresented(false)
        memberSetUndo = undo
    }

    /// 直前の編成適用を取り消す。総額は維持。席は作り直し。Undo が無ければ何もしない
    func didTapUndoMemberSetApply() {
        guard let undo = memberSetUndo else { return }
        applyUpdate(paidSeatKeys: []) { state in
            state.roundingUnit = undo.roundingUnit
            state.groups = undo.groups
        }
    }

    func didTapDeleteMemberSet(id: UUID) {
        sessionStore.deleteMemberSet(id: id)
        refreshSessionChrome()
    }

    /// リワード完了時だけ枠を 1 つ増やす。既に上限なら何もしない
    func didUnlockMemberSetSlot() {
        guard sessionStore.unlockExtraSlot() else { return }
        refreshSessionChrome()
        if sessionChrome.hasEmptyMemberSetSlot {
            sessionChrome.needsSaveMemberSetNamePrompt = true
        }
    }

    func didConsumeSaveMemberSetNamePrompt() {
        guard sessionChrome.needsSaveMemberSetNamePrompt else { return }
        sessionChrome.needsSaveMemberSetNamePrompt = false
    }

    func didPerformMainShare() {
        guard viewState.isShareEnabled else { return }
        hasPerformedMainShareThisBill = true
        if shouldPromptUnpaidReminder {
            sessionChrome.needsUnpaidReminderPrompt = true
        }
    }

    func didDismissMemberSetOffer() {
        sessionStore.markMemberSetOfferConsumed()
        refreshSessionChrome()
    }

    func didTapOpenHistorySheet() {
        setHistorySheetPresented(true)
    }

    func didTapCloseHistorySheet() {
        setHistorySheetPresented(false)
    }

    /// 履歴の会計を続ける。総額・端数・グループ・済を復元。lastBill も上書き
    func didTapRestoreHistory(id: UUID) {
        guard let entry = sessionStore.billHistory.first(where: { $0.id == id }) else { return }
        applyUpdate(paidSeatKeys: Set(entry.snapshot.paidSeatKeys)) { state in
            state.totalAmountText = entry.snapshot.totalAmountText
            state.roundingUnit = entry.snapshot.roundingUnit
            state.groups = entry.snapshot.groups
        }
        sessionStore.saveLastBill(makeSnapshot())
        setHistorySheetPresented(false)
        refreshSessionChrome()
    }

    /// 同じ編成で始める。総額は空、済は空。端数とグループ Draft を載せる
    func didTapStartHistoryComposition(id: UUID) {
        guard let entry = sessionStore.billHistory.first(where: { $0.id == id }) else { return }
        let undo = HistoryCompositionUndo(
            groups: viewState.groups,
            roundingUnit: viewState.roundingUnit,
            totalAmountText: viewState.totalAmountText
        )
        applyUpdate(paidSeatKeys: []) { state in
            state.totalAmountText = ""
            state.roundingUnit = entry.snapshot.roundingUnit
            state.groups = entry.snapshot.groups
        }
        setHistorySheetPresented(false)
        historyCompositionUndo = undo
    }

    func didTapUndoHistoryComposition() {
        guard let undo = historyCompositionUndo else { return }
        applyUpdate(paidSeatKeys: []) { state in
            state.totalAmountText = undo.totalAmountText
            state.roundingUnit = undo.roundingUnit
            state.groups = undo.groups
        }
    }

    func didTapDeleteHistory(id: UUID) {
        sessionStore.deleteHistoryEntry(id: id)
        refreshSessionChrome()
    }

    func didConsumeUnpaidReminderPrompt() {
        sessionStore.markDidPromptUnpaidReminder()
        sessionChrome.needsUnpaidReminderPrompt = false
    }

    func didCompleteUnpaidReminderAuthorization(granted: Bool) {
        if granted {
            reminderScheduler.sync(unpaidCount: collectionState.unpaidSeats.count)
        } else {
            reminderScheduler.sync(unpaidCount: 0)
        }
    }

    private func saveLastBillIfValid() {
        guard viewState.validationIssue == nil else { return }
        sessionStore.saveLastBill(makeSnapshot())
        refreshSessionChrome()
    }

    private func refreshSessionChrome() {
        let next = makeSessionChrome()
        guard next != sessionChrome else { return }
        sessionChrome = next
    }

    private func setMemberSetSheetPresented(_ presented: Bool) {
        guard sessionChrome.isMemberSetSheetPresented != presented else { return }
        sessionChrome.isMemberSetSheetPresented = presented
    }

    private func setHistorySheetPresented(_ presented: Bool) {
        guard sessionChrome.isHistorySheetPresented != presented else { return }
        sessionChrome.isHistorySheetPresented = presented
    }

    private func consumeMemberSetOfferIfNeeded() {
        guard !sessionStore.memberSets.isEmpty else { return }
        sessionStore.markMemberSetOfferConsumed()
    }

    private var shouldPromptUnpaidReminder: Bool {
        !collectionState.unpaidSeats.isEmpty
            && reminderScheduler.authorizationStatus == .notDetermined
            && !sessionStore.didPromptUnpaidReminder
    }

    private func makeSessionChrome() -> SakuttoSplitSessionChrome {
        let lastBill = sessionStore.lastBill
        return SakuttoSplitSessionChrome(
            hasLastBill: lastBill != nil,
            lastBillPreview: Self.makeLastBillPreview(from: lastBill),
            memberSets: sessionStore.memberSets,
            slotCount: sessionStore.slotCount,
            isMemberSetSheetPresented: sessionChrome.isMemberSetSheetPresented,
            needsSaveMemberSetNamePrompt: sessionChrome.needsSaveMemberSetNamePrompt,
            needsUnpaidReminderPrompt: sessionChrome.needsUnpaidReminderPrompt,
            isHistorySheetPresented: sessionChrome.isHistorySheetPresented,
            history: sessionStore.billHistory,
            hasConsumedMemberSetOffer: sessionStore.memberSetOfferConsumed
        )
    }

    /// lastBill があるときだけ。席展開は CollectionSeat.make 相当。幽霊キーは unpaid に数えない
    private static func makeLastBillPreview(from snapshot: BillSnapshot?) -> LastBillPreview? {
        guard let snapshot else { return nil }
        let paidKeys = Set(snapshot.paidSeatKeys)
        let seats = snapshot.groups.flatMap { group in
            CollectionSeat.make(
                groupID: group.id,
                name: group.name,
                count: group.toDomain().count,
                amountPerPerson: 0,
                expandMaxCount: InputLimits.collectionExpandMaxCount,
                paidSeatKeys: paidKeys
            )
        }
        return LastBillPreview(
            totalAmountText: snapshot.totalAmountText,
            unpaidCount: seats.filter { !$0.isPaid }.count,
            seatCount: seats.count
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
        setCollectionState(next)
    }

    private func setCollectionState(_ next: CollectionState) {
        collectionState = next
        refreshUnpaidShareCache()
        reminderScheduler.sync(unpaidCount: next.unpaidSeats.count)
    }

    private func refreshUnpaidShareCache() {
        cachedUnpaidShareText = ShareTextBuilder.buildUnpaid(
            totalAmountText: viewState.totalAmountText,
            unpaidSeats: collectionState.unpaidSeats
        )
        cachedIsUnpaidShareEnabled = viewState.isShareEnabled && !collectionState.unpaidSeats.isEmpty
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

    /// 入力が変わったときだけ 1 回計算し、viewState を 1 回だけ書き換える。
    /// paidSeatKeys が .some なら、入力が同じでも席の済だけ 1 回 reconcile する
    private func applyUpdate(
        paidSeatKeys: Set<String>? = nil,
        _ update: (inout SakuttoSplitViewState) -> Void
    ) {
        var next = viewState
        update(&next)
        next.groups = Self.normalizingGroups(next.groups)
        let inputChanged = next != viewState
        guard inputChanged || paidSeatKeys != nil else { return }
        if inputChanged {
            memberSetUndo = nil
            historyCompositionUndo = nil
            Self.applyCalculation(to: &next, interactor: interactor)
            viewState = next
        }
        reconcileCollection(paidSeatKeys: paidSeatKeys)
        refreshUnpaidShareCache()
    }

    /// 上限で切り、後続の重複 ID だけ振り直す。重複も超過も無ければ入力と ==
    private static func normalizingGroups(_ groups: [AttendeeGroupDraft]) -> [AttendeeGroupDraft] {
        uniquifyingGroupIDs(Array(groups.prefix(InputLimits.groupMaxCount)))
    }

    /// 後続の重複 ID だけ振り直す。重複が無ければ入力と ==
    private static func uniquifyingGroupIDs(_ groups: [AttendeeGroupDraft]) -> [AttendeeGroupDraft] {
        var seen = Set<UUID>()
        return groups.map { group in
            if seen.insert(group.id).inserted {
                return group
            }
            let replacement = AttendeeGroupDraft(
                id: UUID(),
                name: group.name,
                countText: group.countText,
                mode: group.mode,
                fixedAmountText: group.fixedAmountText,
                ratioText: group.ratioText
            )
            seen.insert(replacement.id)
            return replacement
        }
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

private struct MemberSetUndo: Equatable {
    var groups: [AttendeeGroupDraft]
    var roundingUnit: RoundingUnit
}

private struct HistoryCompositionUndo: Equatable {
    var groups: [AttendeeGroupDraft]
    var roundingUnit: RoundingUnit
    var totalAmountText: String
}
