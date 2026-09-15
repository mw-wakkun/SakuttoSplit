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
        let outdated = makeSnapshot(totalAmountText: "12000", schemaVersion: 3)
        let data = try? JSONEncoder().encode(outdated)
        defaults.set(data, forKey: BillSessionStore.lastBillKey)

        XCTAssertNil(store.lastBill)
    }

    func testLastBill_Schema1DataWithoutPaidSeatKeys_IsReadable() throws {
        let groupID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let json: [String: Any] = [
            "schemaVersion": 1,
            "totalAmountText": "35000",
            "roundingUnit": 100,
            "groups": [
                [
                    "id": groupID.uuidString,
                    "name": "部長",
                    "countText": "1",
                    "mode": "fixed",
                    "fixedAmountText": "10000",
                    "ratioText": "1.0"
                ]
            ]
        ]
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: BillSessionStore.lastBillKey)

        let lastBill = try XCTUnwrap(store.lastBill)

        XCTAssertEqual(lastBill.schemaVersion, 1)
        XCTAssertEqual(lastBill.paidSeatKeys, [])
        XCTAssertEqual(lastBill.totalAmountText, "35000")
        XCTAssertEqual(lastBill.groups.map(\.id), [groupID])
    }

    func testLastBill_Schema2WithPaidSeatKeys_RoundTrips() {
        let groupID = UUID()
        let paidKey = CollectionSeatID(groupID: groupID, index: 2).rawValue
        let snapshot = BillSnapshot(
            totalAmountText: "35000",
            roundingUnit: .hundred,
            groups: [AttendeeGroupDraft(id: groupID, name: "一般", countText: "4")],
            paidSeatKeys: [paidKey]
        )

        store.saveLastBill(snapshot)

        XCTAssertEqual(store.lastBill, snapshot)
        XCTAssertEqual(store.lastBill?.schemaVersion, 2)
        XCTAssertEqual(store.lastBill?.paidSeatKeys, [paidKey])
    }

    func testLastBill_SameSnapshot_DoesNotRewrite() {
        let snapshot = makeSnapshot(totalAmountText: "35000")
        store.saveLastBill(snapshot)
        let firstData = defaults.data(forKey: BillSessionStore.lastBillKey)

        store.saveLastBill(snapshot)

        XCTAssertEqual(defaults.data(forKey: BillSessionStore.lastBillKey), firstData)
        XCTAssertEqual(store.lastBill, snapshot)
    }

    // MARK: - history / flags

    func testBillHistory_BrokenData_ReturnsEmpty_KeepsLastBill() {
        let snapshot = makeSnapshot(totalAmountText: "35000")
        store.saveLastBill(snapshot)
        defaults.set(Data("not-json".utf8), forKey: BillSessionStore.billHistoryKey)

        XCTAssertTrue(store.billHistory.isEmpty)
        XCTAssertEqual(store.lastBill, snapshot)
    }

    func testBillHistory_UnknownSnapshotSchema_IsDropped() throws {
        let groupID = UUID()
        let entry = BillHistoryEntry(
            savedAt: Date(timeIntervalSince1970: 1),
            snapshot: BillSnapshot(
                totalAmountText: "1000",
                roundingUnit: .hundred,
                groups: [AttendeeGroupDraft(id: groupID, name: "一般", countText: "1")],
                schemaVersion: 3
            )
        )
        defaults.set(try JSONEncoder().encode([entry]), forKey: BillSessionStore.billHistoryKey)

        XCTAssertTrue(store.billHistory.isEmpty)
    }

    func testSaveLastBill_SameGroupIDs_UpsertsFirstEntry() {
        let groupID = UUID()
        let first = BillSnapshot(
            totalAmountText: "35000",
            roundingUnit: .hundred,
            groups: [AttendeeGroupDraft(id: groupID, name: "一般", countText: "4")],
            paidSeatKeys: []
        )
        store.saveLastBill(first)
        let historyID = store.billHistory[0].id
        let paidKey = CollectionSeatID(groupID: groupID, index: 0).rawValue
        let updated = BillSnapshot(
            totalAmountText: "35000",
            roundingUnit: .hundred,
            groups: first.groups,
            paidSeatKeys: [paidKey]
        )

        store.saveLastBill(updated)

        XCTAssertEqual(store.billHistory.count, 1)
        XCTAssertEqual(store.billHistory[0].id, historyID)
        XCTAssertEqual(store.billHistory[0].snapshot.paidSeatKeys, [paidKey])
        XCTAssertEqual(store.lastBill?.paidSeatKeys, [paidKey])
    }

    func testSaveLastBill_DifferentGroupIDs_InsertsAndCapsAtFive() {
        let ids = (0..<6).map { _ in UUID() }
        for (index, groupID) in ids.enumerated() {
            store.saveLastBill(
                BillSnapshot(
                    totalAmountText: "\(index + 1)000",
                    roundingUnit: .hundred,
                    groups: [AttendeeGroupDraft(id: groupID, name: "一般", countText: "1")]
                )
            )
        }

        XCTAssertEqual(store.billHistory.count, 5)
        XCTAssertEqual(store.billHistory.map { $0.snapshot.groups[0].id }, Array(ids.reversed().prefix(5)))
        XCTAssertEqual(store.lastBill?.groups.map(\.id), [ids[5]])
    }

    func testClearLastBill_DoesNotClearHistory() {
        store.saveLastBill(makeSnapshot(totalAmountText: "35000"))
        XCTAssertEqual(store.billHistory.count, 1)

        store.clearLastBill()

        XCTAssertNil(store.lastBill)
        XCTAssertEqual(store.billHistory.count, 1)
    }

    func testDeleteHistoryEntry_RemovesOnlyThatEntry() {
        let firstID = UUID()
        let secondID = UUID()
        store.saveLastBill(
            BillSnapshot(
                totalAmountText: "1000",
                roundingUnit: .hundred,
                groups: [AttendeeGroupDraft(id: firstID, name: "A", countText: "1")]
            )
        )
        store.saveLastBill(
            BillSnapshot(
                totalAmountText: "2000",
                roundingUnit: .hundred,
                groups: [AttendeeGroupDraft(id: secondID, name: "B", countText: "1")]
            )
        )
        let removeID = store.billHistory[0].id

        store.deleteHistoryEntry(id: removeID)

        XCTAssertEqual(store.billHistory.count, 1)
        XCTAssertEqual(store.billHistory[0].snapshot.groups.map(\.id), [firstID])
        XCTAssertEqual(store.lastBill?.groups.map(\.id), [secondID])
    }

    func testMemberSetOfferConsumed_DefaultsFalse_ThenPersistsTrue() {
        XCTAssertFalse(store.memberSetOfferConsumed)

        store.markMemberSetOfferConsumed()

        XCTAssertTrue(store.memberSetOfferConsumed)
        let reloaded = BillSessionStore(defaults: defaults)
        XCTAssertTrue(reloaded.memberSetOfferConsumed)
    }

    func testDidPromptUnpaidReminder_DefaultsFalse_ThenPersistsTrue() {
        XCTAssertFalse(store.didPromptUnpaidReminder)

        store.markDidPromptUnpaidReminder()

        XCTAssertTrue(store.didPromptUnpaidReminder)
        let reloaded = BillSessionStore(defaults: defaults)
        XCTAssertTrue(reloaded.didPromptUnpaidReminder)
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
