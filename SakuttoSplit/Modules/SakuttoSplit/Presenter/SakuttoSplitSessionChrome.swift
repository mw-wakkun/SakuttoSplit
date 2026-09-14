//
//  SakuttoSplitSessionChrome.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import Foundation

/// 計算の正本とは別の、前回会計・メンバーセットなどの表示用状態
struct SakuttoSplitSessionChrome: Equatable {
    var hasLastBill = false
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
