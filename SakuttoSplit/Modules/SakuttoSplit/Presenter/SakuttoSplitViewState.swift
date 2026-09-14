//
//  SakuttoSplitViewState.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// 割り勘画面の表示状態。Presenter が 1 つの Published として公開する
struct SakuttoSplitViewState: Equatable {
    var totalAmountText: String
    var roundingUnit: RoundingUnit
    var groups: [AttendeeGroupDraft]
    var results: [GroupCalculationResult]
    var difference: Int
    var validationMessage: String?

    static let initial = SakuttoSplitViewState(
        totalAmountText: "",
        roundingUnit: .hundred,
        groups: [
            AttendeeGroupDraft(name: "部長", countText: "1", isFixed: true, fixedAmountText: "10000"),
            AttendeeGroupDraft(name: "一般", countText: "4", isFixed: false, ratioText: "1.0")
        ],
        results: [],
        difference: 0,
        validationMessage: nil
    )
}
