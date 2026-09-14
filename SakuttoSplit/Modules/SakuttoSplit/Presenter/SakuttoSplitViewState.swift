//
//  SakuttoSplitViewState.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// シェアを無効化する入力エラー。計算結果の出し方は変えない
enum SplitValidationIssue: Equatable {
    /// 総額が未入力
    case emptyTotalAmount
    /// 参加者グループが 0 件
    case noGroups
    /// 固定額の合計が総額を超えている
    case fixedAmountExceedsTotal
}

/// 割り勘画面の表示状態。Presenter が 1 つの Published として公開する
struct SakuttoSplitViewState: Equatable {
    var totalAmountText: String
    var roundingUnit: RoundingUnit
    var groups: [AttendeeGroupDraft]
    var results: [GroupCalculationResult]
    var difference: Int
    var shareText: String = ""
    var validationIssue: SplitValidationIssue?

    var isShareEnabled: Bool { validationIssue == nil }

    static let initial = SakuttoSplitViewState(
        totalAmountText: "",
        roundingUnit: .hundred,
        groups: [
            AttendeeGroupDraft(name: "部長", countText: "1", mode: .fixed, fixedAmountText: "10000"),
            AttendeeGroupDraft(name: "一般", countText: "4", mode: .ratio, ratioText: "1.0")
        ],
        results: [],
        difference: 0,
        validationIssue: .emptyTotalAmount
    )
}
