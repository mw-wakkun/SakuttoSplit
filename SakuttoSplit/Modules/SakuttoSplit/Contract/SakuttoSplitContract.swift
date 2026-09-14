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
    /// 起動直後・精算直後の initial ではなく、前回と入力が違うときだけ確認する
    var needsRestoreConfirmation: Bool { get }
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
    /// 現在グループが initial の既定 2 件と違うとき、適用前に確認する
    var needsMemberSetApplyConfirmation: Bool { get }
    func didTapSaveMemberSet(name: String)
    func didTapOpenMemberSetSheet()
    func didTapCloseMemberSetSheet()
    func didTapApplyMemberSet(id: UUID)
    func didTapDeleteMemberSet(id: UUID)
    func didUnlockMemberSetSlot()
}

/// 割り勘計算のユースケース。具象実装を差し替え可能にする
protocol SakuttoSplitInteractorProtocol {
    func calculateBill(_ input: BillCalculationInput) -> BillCalculationOutput
}

/// 広告ユニット ID の供給。DEBUG / Release の切替は具象側
protocol AdConfigurationProviding {
    var bannerAdUnitID: String { get }
    var interstitialAdUnitID: String { get }
    var rewardedAdUnitID: String { get }
}
