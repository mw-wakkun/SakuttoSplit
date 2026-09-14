//
//  BillSessionStoreTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import XCTest
@testable import SakuttoSplit

@MainActor
final class BillSessionStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: BillSessionStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "test.sakuttosplit.session.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        store = BillSessionStore(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    // MARK: - lastBill

    func testLastBill_SaveLoadClear() {
        XCTAssertNil(store.lastBill)

        let snapshot = makeSnapshot(totalAmountText: "35000")
        store.saveLastBill(snapshot)

        XCTAssertEqual(store.lastBill, snapshot)

        store.clearLastBill()
        XCTAssertNil(store.lastBill)
    }

    func testLastBill_BrokenData_ReturnsNil() {
        defaults.set(Data("not-json".utf8), forKey: BillSessionStore.lastBillKey)

        XCTAssertNil(store.lastBill)
    }

    func testLastBill_UnknownSchemaVersion_ReturnsNil() {
        let outdated = makeSnapshot(totalAmountText: "12000", schemaVersion: 2)
        let data = try? JSONEncoder().encode(outdated)
        defaults.set(data, forKey: BillSessionStore.lastBillKey)

        XCTAssertNil(store.lastBill)
    }

    func testLastBill_SameSnapshot_DoesNotRewrite() {
        let snapshot = makeSnapshot(totalAmountText: "35000")
        store.saveLastBill(snapshot)
        let firstData = defaults.data(forKey: BillSessionStore.lastBillKey)

        store.saveLastBill(snapshot)

        XCTAssertEqual(defaults.data(forKey: BillSessionStore.lastBillKey), firstData)
        XCTAssertEqual(store.lastBill, snapshot)
    }

    // MARK: - member sets / slots

    func testSlotCount_DefaultsToOne() {
        XCTAssertEqual(store.slotCount, 1)
        XCTAssertTrue(store.memberSets.isEmpty)
    }

    func testSaveMemberSet_WhenSlotAvailable_Persists() {
        let memberSet = makeMemberSet(name: "いつもの")

        XCTAssertTrue(store.saveMemberSet(memberSet))
        XCTAssertEqual(store.memberSets, [memberSet])
    }

    func testSaveMemberSet_WhenFull_DoesNotWriteSecond() {
        XCTAssertTrue(store.saveMemberSet(makeMemberSet(name: "1件目")))

        XCTAssertFalse(store.saveMemberSet(makeMemberSet(name: "2件目")))
        XCTAssertEqual(store.memberSets.map(\.name), ["1件目"])
    }

    func testSaveMemberSet_UpdateExisting_WhenFull_Succeeds() {
        let original = makeMemberSet(name: "1件目")
        XCTAssertTrue(store.saveMemberSet(original))
        let updated = MemberSet(
            id: original.id,
            name: "改名",
            roundingUnit: original.roundingUnit,
            groups: original.groups,
            createdAt: original.createdAt
        )

        XCTAssertTrue(store.saveMemberSet(updated))
        XCTAssertEqual(store.memberSets.map(\.name), ["改名"])
        XCTAssertEqual(store.memberSets.map(\.id), [original.id])
    }

    func testUnlockExtraSlot_IncrementsUntilThree() {
        XCTAssertTrue(store.unlockExtraSlot())
        XCTAssertEqual(store.slotCount, 2)
        XCTAssertTrue(store.saveMemberSet(makeMemberSet(name: "1")))
        XCTAssertTrue(store.saveMemberSet(makeMemberSet(name: "2")))

        XCTAssertTrue(store.unlockExtraSlot())
        XCTAssertEqual(store.slotCount, 3)
        XCTAssertTrue(store.saveMemberSet(makeMemberSet(name: "3")))

        XCTAssertFalse(store.unlockExtraSlot())
        XCTAssertEqual(store.slotCount, 3)
        XCTAssertFalse(store.saveMemberSet(makeMemberSet(name: "4")))
        XCTAssertEqual(store.memberSets.count, 3)
    }

    func testDeleteMemberSet_DoesNotDecreaseSlotCount() {
        XCTAssertTrue(store.unlockExtraSlot())
        XCTAssertEqual(store.slotCount, 2)
        let first = makeMemberSet(name: "残す")
        let second = makeMemberSet(name: "消す")
        XCTAssertTrue(store.saveMemberSet(first))
        XCTAssertTrue(store.saveMemberSet(second))

        store.deleteMemberSet(id: second.id)

        XCTAssertEqual(store.memberSets.map(\.name), ["残す"])
        XCTAssertEqual(store.slotCount, 2)
    }

    func testMemberSets_BrokenData_ReturnsEmpty() {
        defaults.set(Data("not-json".utf8), forKey: BillSessionStore.memberSetsKey)

        XCTAssertTrue(store.memberSets.isEmpty)
    }

    func testSlotCount_StoredFour_ClampsToThree() {
        defaults.set(4, forKey: BillSessionStore.slotCountKey)

        XCTAssertEqual(store.slotCount, 3)
        XCTAssertFalse(store.unlockExtraSlot())
        XCTAssertEqual(store.slotCount, 3)
    }

    private func makeSnapshot(
        totalAmountText: String,
        schemaVersion: Int = BillSnapshot.currentSchemaVersion
    ) -> BillSnapshot {
        BillSnapshot(
            totalAmountText: totalAmountText,
            roundingUnit: .hundred,
            groups: [
                AttendeeGroupDraft(name: "部長", countText: "1", mode: .fixed, fixedAmountText: "10000"),
                AttendeeGroupDraft(name: "一般", countText: "4", mode: .ratio, ratioText: "1.0")
            ],
            schemaVersion: schemaVersion
        )
    }

    private func makeMemberSet(name: String) -> MemberSet {
        MemberSet(
            name: name,
            roundingUnit: .hundred,
            groups: [AttendeeGroupDraft(name: "部長", countText: "1", mode: .fixed, fixedAmountText: "10000")],
            createdAt: Date(timeIntervalSince1970: 1_779_000_000)
        )
    }
}
