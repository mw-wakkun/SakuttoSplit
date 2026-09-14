//
//  BillSessionStore.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import Foundation

/// 前回会計とメンバーセット。UserDefaults のキーはここだけ
struct BillSessionStore: BillSessionStoring {
    static let lastBillKey = "session.lastBill"
    static let memberSetsKey = "session.memberSets"
    static let slotCountKey = "session.memberSetSlotCount"
    static let minSlotCount = 1
    static let maxSlotCount = 3

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastBill: BillSnapshot? {
        guard let data = defaults.data(forKey: Self.lastBillKey) else { return nil }
        guard let snapshot = try? decoder.decode(BillSnapshot.self, from: data) else { return nil }
        guard snapshot.isReadableSchema else { return nil }
        return snapshot
    }

    func saveLastBill(_ snapshot: BillSnapshot) {
        guard lastBill != snapshot else { return }
        guard let data = encode(snapshot) else { return }
        defaults.set(data, forKey: Self.lastBillKey)
    }

    func clearLastBill() {
        defaults.removeObject(forKey: Self.lastBillKey)
    }

    var memberSets: [MemberSet] {
        guard let data = defaults.data(forKey: Self.memberSetsKey) else { return [] }
        guard let sets = try? decoder.decode([MemberSet].self, from: data) else { return [] }
        return sets.filter(\.isCurrentSchema)
    }

    @discardableResult
    func saveMemberSet(_ memberSet: MemberSet) -> Bool {
        var sets = memberSets
        if let index = sets.firstIndex(where: { $0.id == memberSet.id }) {
            sets[index] = memberSet
            persistMemberSets(sets)
            return true
        }
        guard sets.count < slotCount else { return false }
        sets.append(memberSet)
        persistMemberSets(sets)
        return true
    }

    func deleteMemberSet(id: UUID) {
        var sets = memberSets
        sets.removeAll { $0.id == id }
        persistMemberSets(sets)
    }

    var slotCount: Int {
        guard defaults.object(forKey: Self.slotCountKey) != nil else {
            return Self.minSlotCount
        }
        let stored = defaults.integer(forKey: Self.slotCountKey)
        return min(Self.maxSlotCount, max(Self.minSlotCount, stored))
    }

    @discardableResult
    func unlockExtraSlot() -> Bool {
        let current = slotCount
        guard current < Self.maxSlotCount else { return false }
        defaults.set(current + 1, forKey: Self.slotCountKey)
        return true
    }

    private func persistMemberSets(_ sets: [MemberSet]) {
        guard let data = encode(sets) else { return }
        defaults.set(data, forKey: Self.memberSetsKey)
    }

    private func encode<T: Encodable>(_ value: T) -> Data? {
        try? encoder.encode(value)
    }
}
