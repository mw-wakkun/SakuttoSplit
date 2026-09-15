//
//  SakuttoSplitContract.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Combine
import Foundation

/// View が描画する状態と、ユーザー操作の Intent を公開する
@MainActor
protocol SakuttoSplitPresenterProtocol: ObservableObject {
    var viewState: SakuttoSplitViewState { get }
    var sessionChrome: SakuttoSplitSessionChrome { get }
    /// 席の済/未済。計算の viewState とは独立する。妥当でない入力では空
    var collectionState: CollectionState { get }
    /// 未払い席だけの再シェア文。席が無い・全員済は空文字
    var unpaidShareText: String { get }
    /// 未払いが 1 席以上かつメインシェアが有効なときだけ true
    var isUnpaidShareEnabled: Bool { get }
    /// 起動直後・精算直後の initial ではなく、前回と入力が違うときだけ確認する
    var needsRestoreConfirmation: Bool { get }
    /// initial かつ lastBill があるときだけ再開カードを出す
    var showsResumeCard: Bool { get }
    /// initial ではなく lastBill があるときだけ左上復元を出す
    var showsRestoreToolbar: Bool { get }
    /// セット 0・空き枠あり・この会計でメインシェア済み・未消費のときだけ
    var showsMemberSetOffer: Bool { get }
    /// 総額・端数・グループの中身が起動時と同じ。履歴の dirty 判定に使う
    var isInitialInput: Bool { get }
    var reminderScheduler: any UnpaidReminderScheduling { get }
    func didChangeTotalAmount(_ text: String)
    func didChangeRoundingUnit(_ unit: RoundingUnit)
    func didChangeGroupName(id: UUID, name: String)
    func didChangeGroupCount(id: UUID, countText: String)
    func didChangePaymentMode(id: UUID, mode: PaymentMode)
    func didChangeFixedAmount(id: UUID, text: String)
    func didChangeRatio(id: UUID, text: String)
    func didTapAddGroup()
    func didTapRemoveGroup(id: UUID)
    func didTapSettleComplete()
    func didEnterBackground()
    func didTapRestoreLastBill()
    /// その席の済/未済だけ反転する。計算しない
    func didTapToggleCollectionSeat(id: CollectionSeatID)
    /// そのグループの席をすべて済にする。計算しない。すでに全員済なら何もしない
    func didTapMarkGroupCollectionPaid(groupID: UUID)
    /// 回収ボードの全席を済にする。計算しない。すでに全員済なら何もしない
    func didTapMarkAllCollectionPaid()
    func didTapSaveMemberSet(name: String)
    func didTapOpenMemberSetSheet()
    func didTapCloseMemberSetSheet()
    func didTapApplyMemberSet(id: UUID)
    /// 直前の編成適用を取り消す。総額は維持。席は作り直し
    func didTapUndoMemberSetApply()
    func didTapDeleteMemberSet(id: UUID)
    func didUnlockMemberSetSlot()
    /// 保存名 Alert を出したあと、chrome のフラグを下ろす
    func didConsumeSaveMemberSetNamePrompt()
    func didPerformMainShare()
    func didDismissMemberSetOffer()
    func didTapOpenHistorySheet()
    func didTapCloseHistorySheet()
    func didTapRestoreHistory(id: UUID)
    func didTapStartHistoryComposition(id: UUID)
    func didTapUndoHistoryComposition()
    func didTapDeleteHistory(id: UUID)
    func didConsumeUnpaidReminderPrompt()
    func didCompleteUnpaidReminderAuthorization(granted: Bool)
}

/// 割り勘計算のユースケース。具象実装を差し替え可能にする
protocol SakuttoSplitInteractorProtocol {
    func calculateBill(_ input: BillCalculationInput) -> BillCalculationOutput
}

/// 広告ユニット ID の供給。App Store 本番以外はテストユニット。切替は具象側
protocol AdConfigurationProviding {
    var bannerAdUnitID: String { get }
    var interstitialAdUnitID: String { get }
    var rewardedAdUnitID: String { get }
}
