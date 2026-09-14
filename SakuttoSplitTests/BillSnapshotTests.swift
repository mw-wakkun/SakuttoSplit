//
//  BillSnapshotTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import XCTest
@testable import SakuttoSplit

@MainActor
final class BillSnapshotTests: XCTestCase {

    func testCodableRoundTrip_PreservesTotalRoundingAndGroups() throws {
        let managerID = UUID()
        let staffID = UUID()
        let snapshot = BillSnapshot(
            totalAmountText: "35000",
            roundingUnit: .hundred,
            groups: [
                AttendeeGroupDraft(
                    id: managerID,
                    name: "部長",
                    countText: "1",
                    mode: .fixed,
                    fixedAmountText: "10000",
                    ratioText: "1.0"
                ),
                AttendeeGroupDraft(
                    id: staffID,
                    name: "一般",
                    countText: "4",
                    mode: .ratio,
                    fixedAmountText: "0",
                    ratioText: "1.0"
                )
            ]
        )

        let decoded = try roundTrip(snapshot)

        XCTAssertEqual(decoded.schemaVersion, BillSnapshot.currentSchemaVersion)
        XCTAssertEqual(decoded.totalAmountText, "35000")
        XCTAssertEqual(decoded.roundingUnit, .hundred)
        XCTAssertEqual(decoded.groups.count, 2)
        XCTAssertEqual(decoded.groups[0].id, managerID)
        XCTAssertEqual(decoded.groups[0].name, "部長")
        XCTAssertEqual(decoded.groups[0].mode, .fixed)
        XCTAssertEqual(decoded.groups[0].fixedAmountText, "10000")
        XCTAssertEqual(decoded.groups[1].id, staffID)
        XCTAssertEqual(decoded.groups[1].countText, "4")
        XCTAssertEqual(decoded.groups[1].mode, .ratio)
        XCTAssertEqual(decoded, snapshot)
    }

    func testCodableRoundTrip_DuplicateGroupNames_AreDistinguishedByID() throws {
        let firstID = UUID()
        let secondID = UUID()
        let snapshot = BillSnapshot(
            totalAmountText: "20000",
            roundingUnit: .thousand,
            groups: [
                AttendeeGroupDraft(id: firstID, name: "一般", countText: "2", mode: .ratio, ratioText: "1.0"),
                AttendeeGroupDraft(id: secondID, name: "一般", countText: "3", mode: .ratio, ratioText: "1.5")
            ]
        )

        let decoded = try roundTrip(snapshot)

        XCTAssertEqual(decoded.groups.map(\.name), ["一般", "一般"])
        XCTAssertEqual(decoded.groups.map(\.id), [firstID, secondID])
        XCTAssertEqual(decoded.groups.map(\.countText), ["2", "3"])
        XCTAssertEqual(Set(decoded.groups.map(\.id)).count, 2)
    }

    func testCodableRoundTrip_AllRoundingUnits() throws {
        for unit in RoundingUnit.allCases {
            let snapshot = BillSnapshot(
                totalAmountText: "1000",
                roundingUnit: unit,
                groups: [AttendeeGroupDraft(name: "全員")]
            )
            let decoded = try roundTrip(snapshot)
            XCTAssertEqual(decoded.roundingUnit, unit)
        }
    }

    func testDecode_Schema1JSONWithoutPaidSeatKeys_DefaultsToEmpty() throws {
        let groupID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let data = try schema1JSON(groupID: groupID, totalAmountText: "35000")

        let decoded = try JSONDecoder().decode(BillSnapshot.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertTrue(decoded.isReadableSchema)
        XCTAssertFalse(decoded.isCurrentSchema)
        XCTAssertEqual(decoded.paidSeatKeys, [])
        XCTAssertEqual(decoded.totalAmountText, "35000")
        XCTAssertEqual(decoded.roundingUnit, .hundred)
        XCTAssertEqual(decoded.groups.map(\.id), [groupID])
        XCTAssertEqual(decoded.groups.map(\.name), ["部長"])
    }

    func testCodableRoundTrip_Schema2_PreservesPaidSeatKeys() throws {
        let groupID = UUID()
        let paidKey = CollectionSeatID(groupID: groupID, index: 0).rawValue
        let snapshot = BillSnapshot(
            totalAmountText: "35000",
            roundingUnit: .hundred,
            groups: [AttendeeGroupDraft(id: groupID, name: "一般", countText: "4")],
            paidSeatKeys: [paidKey]
        )

        let decoded = try roundTrip(snapshot)

        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertEqual(decoded.schemaVersion, BillSnapshot.currentSchemaVersion)
        XCTAssertTrue(decoded.isCurrentSchema)
        XCTAssertTrue(decoded.isReadableSchema)
        XCTAssertEqual(decoded.paidSeatKeys, [paidKey])
        XCTAssertEqual(decoded, snapshot)
    }

    func testEncode_AlwaysWritesPaidSeatKeysAndSchema2() throws {
        let snapshot = BillSnapshot(
            totalAmountText: "1000",
            roundingUnit: .one,
            groups: [AttendeeGroupDraft(name: "全員")]
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try JSONEncoder().encode(snapshot)) as? [String: Any]
        )

        XCTAssertEqual(object["schemaVersion"] as? Int, 2)
        XCTAssertEqual(object["paidSeatKeys"] as? [String], [])
    }

    private func roundTrip(_ snapshot: BillSnapshot) throws -> BillSnapshot {
        let data = try JSONEncoder().encode(snapshot)
        return try JSONDecoder().decode(BillSnapshot.self, from: data)
    }

    private func schema1JSON(groupID: UUID, totalAmountText: String) throws -> Data {
        let json: [String: Any] = [
            "schemaVersion": 1,
            "totalAmountText": totalAmountText,
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
        return try JSONSerialization.data(withJSONObject: json)
    }
}
