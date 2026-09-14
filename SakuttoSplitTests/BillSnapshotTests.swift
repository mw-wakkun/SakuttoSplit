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

    private func roundTrip(_ snapshot: BillSnapshot) throws -> BillSnapshot {
        let data = try JSONEncoder().encode(snapshot)
        return try JSONDecoder().decode(BillSnapshot.self, from: data)
    }
}
