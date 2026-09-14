//
//  SakuttoSplitSessionChrome.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import Foundation

/// 再開カード用の前回会計プレビュー。Store の JSON 形は変えない
struct LastBillPreview: Equatable {
    var totalAmountText: String
    var unpaidCount: Int
    var seatCount: Int
}

/// 計算の正本とは別の、前回会計・メンバーセットなどの表示用状態
struct SakuttoSplitSessionChrome: Equatable {
    var hasLastBill = false
    var lastBillPreview: LastBillPreview? = nil
    var memberSets: [MemberSet] = []
    var slotCount = BillSessionStore.minSlotCount
    var isMemberSetSheetPresented = false

    var hasEmptyMemberSetSlot: Bool {
        memberSets.count < slotCount
    }

    var canUnlockMemberSetSlot: Bool {
        slotCount < BillSessionStore.maxSlotCount
    }
}
