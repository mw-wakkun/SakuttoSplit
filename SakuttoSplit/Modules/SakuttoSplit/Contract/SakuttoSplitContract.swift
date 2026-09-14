//
//  SakuttoSplitContract.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Combine
import Foundation
import SwiftUI

/// View が描画する状態と、ユーザー操作の Intent を公開する
@MainActor
protocol SakuttoSplitPresentable: ObservableObject {
    var viewState: SakuttoSplitViewState { get }
    func didChangeTotalAmount(_ text: String)
    func didChangeRoundingUnit(_ unit: RoundingUnit)
    func didChangeGroupName(id: UUID, name: String)
    func didChangeGroupCount(id: UUID, countText: String)
    func didChangePaymentMode(id: UUID, mode: PaymentMode)
    func didChangeFixedAmount(id: UUID, text: String)
    func didChangeRatio(id: UUID, text: String)
    func didTapAddGroup()
    func didTapRemoveGroup(id: UUID)
    func shareText() -> String
}

/// 割り勘計算のユースケース。具象実装を差し替え可能にする
protocol SakuttoSplitInteractorProtocol {
    func calculateBill(_ input: BillCalculationInput) -> BillCalculationOutput
}

/// モジュール組み立て。戻り値は型消去しない
@MainActor
protocol SakuttoSplitRouterProtocol {
    static func assembleModule() -> SakuttoSplitView
}

/// 広告ユニット ID の供給
protocol AdConfigurationProviding {
    var bannerAdUnitID: String { get }
}
