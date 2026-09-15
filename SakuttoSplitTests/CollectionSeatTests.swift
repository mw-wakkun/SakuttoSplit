//
//  CollectionSeatTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import XCTest
@testable import SakuttoSplit

final class CollectionSeatTests: XCTestCase {

    func testSeatID_RawValue_IsGroupUUIDAndZeroBasedIndex() {
        let groupID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

        let id = CollectionSeatID(groupID: groupID, index: 3)

        XCTAssertEqual(id.rawValue, "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE:3")
        XCTAssertEqual(CollectionSeatID(rawValue: id.rawValue), id)
    }

    func testSeatID_RawValue_RejectsMalformedKeys() {
        XCTAssertNil(CollectionSeatID(rawValue: "not-a-uuid:0"))
        XCTAssertNil(CollectionSeatID(rawValue: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        XCTAssertNil(CollectionSeatID(rawValue: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE:-1"))
        XCTAssertNil(CollectionSeatID(rawValue: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE:x"))
    }

    func testMakeSeats_Count1_MakesOneSeat_LabelStartsAtOne() {
        let groupID = UUID()
        let seats = CollectionSeat.make(
            groupID: groupID,
            name: "部長",
            count: 1,
            amountPerPerson: 10000,
            expandMaxCount: InputLimits.collectionExpandMaxCount
        )

        XCTAssertEqual(seats.count, 1)
        XCTAssertEqual(seats[0].id.rawValue, "\(groupID.uuidString):0")
        XCTAssertEqual(seats[0].label, "部長 1")
        XCTAssertEqual(seats[0].groupName, "部長")
        XCTAssertEqual(seats[0].displayNumber, 1)
        XCTAssertEqual(seats[0].amountPerPerson, 10000)
        XCTAssertFalse(seats[0].isPaid)
    }

    func testMakeSeats_Count4_MakesFourSeats_LabelsAreOneBased() {
        let groupID = UUID()
        let seats = CollectionSeat.make(
            groupID: groupID,
            name: "一般",
            count: 4,
            amountPerPerson: 6200,
            expandMaxCount: InputLimits.collectionExpandMaxCount
        )

        XCTAssertEqual(seats.count, 4)
        XCTAssertEqual(seats.map(\.label), ["一般 1", "一般 2", "一般 3", "一般 4"])
        XCTAssertEqual(seats.map(\.displayNumber), [1, 2, 3, 4])
        XCTAssertEqual(seats.map(\.id.index), [0, 1, 2, 3])
        XCTAssertEqual(seats.map(\.id.rawValue), (0...3).map { "\(groupID.uuidString):\($0)" })
        XCTAssertTrue(seats.allSatisfy { $0.amountPerPerson == 6200 })
        XCTAssertTrue(seats.allSatisfy { !$0.isPaid })
    }

    func testMakeSeats_Count20_ExpandsToTwentySeats() {
        let groupID = UUID()
        let seats = CollectionSeat.make(
            groupID: groupID,
            name: "一般",
            count: 20,
            amountPerPerson: 1000,
            expandMaxCount: InputLimits.collectionExpandMaxCount
        )

        XCTAssertEqual(InputLimits.collectionExpandMaxCount, 20)
        XCTAssertEqual(seats.count, 20)
        XCTAssertEqual(seats.first?.label, "一般 1")
        XCTAssertEqual(seats.last?.label, "一般 20")
        XCTAssertEqual(seats.last?.id.rawValue, "\(groupID.uuidString):19")
    }

    func testMakeSeats_Count21_CollapsesToOneRowWithGroupName() {
        let groupID = UUID()
        let seats = CollectionSeat.make(
            groupID: groupID,
            name: "一般",
            count: 21,
            amountPerPerson: 1000,
            expandMaxCount: InputLimits.collectionExpandMaxCount
        )

        XCTAssertEqual(seats.count, 1)
        XCTAssertEqual(seats[0].label, "一般")
        XCTAssertEqual(seats[0].groupName, "一般")
        XCTAssertNil(seats[0].displayNumber)
        XCTAssertEqual(seats[0].id.index, 0)
        XCTAssertEqual(seats[0].id.rawValue, "\(groupID.uuidString):0")
        XCTAssertEqual(seats[0].amountPerPerson, 1000)
        XCTAssertFalse(seats[0].isPaid)
    }

    func testMakeSeats_PaidSeatKeys_MarkMatchingIDsOnly() {
        let groupID = UUID()
        let paid = CollectionSeatID(groupID: groupID, index: 1).rawValue
        let seats = CollectionSeat.make(
            groupID: groupID,
            name: "一般",
            count: 4,
            amountPerPerson: 6200,
            expandMaxCount: InputLimits.collectionExpandMaxCount,
            paidSeatKeys: [paid, "missing:0"]
        )

        XCTAssertEqual(seats.map(\.isPaid), [false, true, false, false])
    }

    func testMakeSeats_CountZero_ReturnsEmpty() {
        let seats = CollectionSeat.make(
            groupID: UUID(),
            name: "欠席",
            count: 0,
            amountPerPerson: 1000,
            expandMaxCount: InputLimits.collectionExpandMaxCount
        )

        XCTAssertTrue(seats.isEmpty)
    }

    func testReconcile_MissingResultForGroup_UsesZeroAmount() {
        let groupID = UUID()
        let groups = [
            AttendeeGroupDraft(
                id: groupID,
                name: "一般",
                countText: "2",
                mode: .ratio,
                ratioText: "1.0"
            )
        ]

        let state = CollectionState.reconcile(
            groups: groups,
            results: [],
            paidSeatKeys: [],
            expandMaxCount: InputLimits.collectionExpandMaxCount
        )

        XCTAssertEqual(state.seats.count, 2)
        XCTAssertTrue(state.seats.allSatisfy { $0.amountPerPerson == 0 })
        XCTAssertEqual(state.unpaidSeats.count, 2)
    }

    /// 同 groupID の results が 2 件でも trap せず、後勝ちの金額を使う
    func testReconcile_DuplicateResultGroupIDs_DoesNotTrap_UsesLastAmount() {
        let groupID = UUID()
        let groups = [
            AttendeeGroupDraft(
                id: groupID,
                name: "一般",
                countText: "2",
                mode: .ratio,
                ratioText: "1.0"
            )
        ]
        let results = [
            GroupCalculationResult(groupID: groupID, name: "一般", amountPerPerson: 1000, total: 2000),
            GroupCalculationResult(groupID: groupID, name: "一般", amountPerPerson: 2500, total: 5000)
        ]

        let state = CollectionState.reconcile(
            groups: groups,
            results: results,
            paidSeatKeys: [],
            expandMaxCount: InputLimits.collectionExpandMaxCount
        )

        XCTAssertEqual(state.seats.count, 2)
        XCTAssertTrue(state.seats.allSatisfy { $0.amountPerPerson == 2500 })
        XCTAssertEqual(state.seats.map(\.id.groupID), [groupID, groupID])
    }
}
