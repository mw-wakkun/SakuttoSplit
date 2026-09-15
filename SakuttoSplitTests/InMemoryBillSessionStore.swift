//
//  InMemoryBillSessionStore.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import Foundation
@testable import SakuttoSplit

/// テスト用。UserDefaults を叩かず、本番 Store と同じ枠ルールを持つ
final class InMemoryBillSessionStore: BillSessionStoring {
    private(set) var lastBill: BillSnapshot?
    private(set) var memberSets: [MemberSet] = []
    private(set) var slotCount: Int
    private(set) var saveLastBillCallCount = 0
    private(set) var billHistory: [BillHistoryEntry] = []
    private(set) var memberSetOfferConsumed = false
    private(set) var didPromptUnpaidReminder = false

    init(slotCount: Int = BillSessionStore.minSlotCount) {
        self.slotCount = min(
            BillSessionStore.maxSlotCount,
            max(BillSessionStore.minSlotCount, slotCount)
        )
    }

    func saveLastBill(_ snapshot: BillSnapshot) {
        saveLastBillCallCount += 1
        lastBill = snapshot
        billHistory = BillHistoryEntry.upserting(snapshot, into: billHistory)
    }

    func clearLastBill() {
        lastBill = nil
    }

    @discardableResult
    func saveMemberSet(_ memberSet: MemberSet) -> Bool {
        if let index = memberSets.firstIndex(where: { $0.id == memberSet.id }) {
            memberSets[index] = memberSet
            return true
        }
        guard memberSets.count < slotCount else { return false }
        memberSets.append(memberSet)
        return true
    }

    func deleteMemberSet(id: UUID) {
        memberSets.removeAll { $0.id == id }
    }

    @discardableResult
    func unlockExtraSlot() -> Bool {
        guard slotCount < BillSessionStore.maxSlotCount else { return false }
        slotCount += 1
        return true
    }

    func deleteHistoryEntry(id: UUID) {
        billHistory.removeAll { $0.id == id }
    }

    func markMemberSetOfferConsumed() {
        memberSetOfferConsumed = true
    }

    func markDidPromptUnpaidReminder() {
        didPromptUnpaidReminder = true
    }
}
