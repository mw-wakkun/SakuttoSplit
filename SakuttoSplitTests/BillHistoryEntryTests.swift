//
//  BillHistoryEntryTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import XCTest
@testable import SakuttoSplit

final class BillHistoryEntryTests: XCTestCase {

    func testCodableRoundTrip_WrapsSchema2Snapshot() throws {
        let groupID = UUID()
        let paidKey = CollectionSeatID(groupID: groupID, index: 0).rawValue
        let savedAt = Date(timeIntervalSince1970: 1_779_000_000)
        let entry = BillHistoryEntry(
            savedAt: savedAt,
            snapshot: BillSnapshot(
                totalAmountText: "35000",
                roundingUnit: .hundred,
                groups: [AttendeeGroupDraft(id: groupID, name: "一般", countText: "4")],
                paidSeatKeys: [paidKey]
            )
        )

        let decoded = try JSONDecoder().decode(
            BillHistoryEntry.self,
            from: try JSONEncoder().encode(entry)
        )

        XCTAssertEqual(decoded.schemaVersion, BillHistoryEntry.currentSchemaVersion)
        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.savedAt, savedAt)
        XCTAssertEqual(decoded.snapshot.schemaVersion, 2)
        XCTAssertEqual(decoded.snapshot.paidSeatKeys, [paidKey])
        XCTAssertEqual(decoded, entry)
    }

    func testDecode_WrapsSchema1SnapshotWithoutPaidSeatKeys() throws {
        let groupID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let entryID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let json: [String: Any] = [
            "schemaVersion": 1,
            "id": entryID.uuidString,
            "savedAt": 1_779_000_000.0,
            "snapshot": [
                "schemaVersion": 1,
                "totalAmountText": "12000",
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
        ]

        let decoded = try JSONDecoder().decode(
            BillHistoryEntry.self,
            from: try JSONSerialization.data(withJSONObject: json)
        )

        XCTAssertEqual(decoded.id, entryID)
        XCTAssertEqual(decoded.snapshot.schemaVersion, 1)
        XCTAssertTrue(decoded.snapshot.isReadableSchema)
        XCTAssertEqual(decoded.snapshot.paidSeatKeys, [])
        XCTAssertEqual(decoded.snapshot.groups.map(\.id), [groupID])
        XCTAssertEqual(decoded.unpaidCount, 1)
    }

    func testUnpaidCount_GroupWith21People_CollapsesToOneSeat() {
        let groupID = UUID()
        let unpaid = BillHistoryEntry(
            savedAt: Date(timeIntervalSince1970: 1),
            snapshot: BillSnapshot(
                totalAmountText: "21000",
                roundingUnit: .hundred,
                groups: [AttendeeGroupDraft(id: groupID, name: "一般", countText: "21")],
                paidSeatKeys: []
            )
        )
        let paidKey = CollectionSeatID(groupID: groupID, index: 0).rawValue
        let paid = BillHistoryEntry(
            savedAt: Date(timeIntervalSince1970: 1),
            snapshot: BillSnapshot(
                totalAmountText: "21000",
                roundingUnit: .hundred,
                groups: unpaid.snapshot.groups,
                paidSeatKeys: [paidKey]
            )
        )

        XCTAssertEqual(unpaid.unpaidCount, 1)
        XCTAssertEqual(paid.unpaidCount, 0)
    }

    func testUnpaidCount_MixedExpandedAndCollapsedGroups() {
        let collapsedID = UUID()
        let expandedID = UUID()
        let paidExpanded = CollectionSeatID(groupID: expandedID, index: 0).rawValue
        let entry = BillHistoryEntry(
            savedAt: Date(timeIntervalSince1970: 1),
            snapshot: BillSnapshot(
                totalAmountText: "50000",
                roundingUnit: .hundred,
                groups: [
                    AttendeeGroupDraft(id: collapsedID, name: "大人数", countText: "21"),
                    AttendeeGroupDraft(id: expandedID, name: "一般", countText: "4")
                ],
                paidSeatKeys: [paidExpanded]
            )
        )

        // 21人は席1（未済）+ 展開4席のうち1済 → 未払い 1+3
        XCTAssertEqual(entry.unpaidCount, 4)
    }

    func testCompositionPreview_MatchesMemberSetFormat() {
        let entry = BillHistoryEntry(
            savedAt: Date(timeIntervalSince1970: 1),
            snapshot: BillSnapshot(
                totalAmountText: "35000",
                roundingUnit: .hundred,
                groups: [
                    AttendeeGroupDraft(name: "部長", countText: "1", mode: .fixed, fixedAmountText: "10000"),
                    AttendeeGroupDraft(name: "一般", countText: "4", mode: .ratio, ratioText: "1.0")
                ]
            )
        )

        XCTAssertEqual(entry.compositionPreview, "部長 1 / 一般 4 · 100円")
    }

    func testUpserting_EmptyHistory_InsertsOne() {
        let groupID = UUID()
        let now = Date(timeIntervalSince1970: 1)

        let result = BillHistoryEntry.upserting(
            makeSnapshot(groupID: groupID, totalAmountText: "10000"),
            into: [],
            now: now,
            maxCount: 5
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].savedAt, now)
        XCTAssertEqual(result[0].snapshot.groups.map(\.id), [groupID])
    }

    func testUpserting_SameGroupIDs_OverwritesFirstAndKeepsID() {
        let groupID = UUID()
        let originalID = UUID()
        let first = BillHistoryEntry(
            id: originalID,
            savedAt: Date(timeIntervalSince1970: 1),
            snapshot: makeSnapshot(groupID: groupID, totalAmountText: "10000", paidSeatKeys: [])
        )
        let updated = makeSnapshot(
            groupID: groupID,
            totalAmountText: "10000",
            paidSeatKeys: [CollectionSeatID(groupID: groupID, index: 0).rawValue]
        )

        let result = BillHistoryEntry.upserting(
            updated,
            into: [first],
            now: Date(timeIntervalSince1970: 2),
            maxCount: 5
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, originalID)
        XCTAssertEqual(result[0].savedAt, Date(timeIntervalSince1970: 2))
        XCTAssertEqual(result[0].snapshot.paidSeatKeys, updated.paidSeatKeys)
    }

    func testUpserting_DifferentGroupIDs_InsertsAtFront() {
        let firstGroup = UUID()
        let secondGroup = UUID()
        let existing = BillHistoryEntry(
            savedAt: Date(timeIntervalSince1970: 1),
            snapshot: makeSnapshot(groupID: firstGroup, totalAmountText: "10000")
        )

        let result = BillHistoryEntry.upserting(
            makeSnapshot(groupID: secondGroup, totalAmountText: "20000"),
            into: [existing],
            now: Date(timeIntervalSince1970: 2),
            maxCount: 5
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].snapshot.groups.map(\.id), [secondGroup])
        XCTAssertEqual(result[1].id, existing.id)
    }

    func testUpserting_OverMaxCount_DropsOldest() {
        var history: [BillHistoryEntry] = []
        let ids = (0..<6).map { _ in UUID() }
        for (index, groupID) in ids.enumerated() {
            history = BillHistoryEntry.upserting(
                makeSnapshot(groupID: groupID, totalAmountText: "\(index + 1)000"),
                into: history,
                now: Date(timeIntervalSince1970: TimeInterval(index)),
                maxCount: 5
            )
        }

        XCTAssertEqual(history.count, 5)
        XCTAssertEqual(history.map { $0.snapshot.groups[0].id }, Array(ids.reversed().prefix(5)))
        XCTAssertFalse(history.contains { $0.snapshot.groups[0].id == ids[0] })
    }

    private func makeSnapshot(
        groupID: UUID,
        totalAmountText: String,
        paidSeatKeys: [String] = []
    ) -> BillSnapshot {
        BillSnapshot(
            totalAmountText: totalAmountText,
            roundingUnit: .hundred,
            groups: [AttendeeGroupDraft(id: groupID, name: "一般", countText: "1")],
            paidSeatKeys: paidSeatKeys
        )
    }
}
