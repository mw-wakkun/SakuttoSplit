//
//  MemberSetTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import XCTest
@testable import SakuttoSplit

@MainActor
final class MemberSetTests: XCTestCase {

    func testCodableRoundTrip_PreservesNameGroupsAndCreatedAt() throws {
        let id = UUID()
        let groupID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_779_000_000)
        let memberSet = MemberSet(
            id: id,
            name: "いつもの飲み会",
            roundingUnit: .fiveHundred,
            groups: [
                AttendeeGroupDraft(
                    id: groupID,
                    name: "部長",
                    countText: "1",
                    mode: .fixed,
                    fixedAmountText: "10000"
                )
            ],
            createdAt: createdAt
        )

        let data = try JSONEncoder().encode(memberSet)
        let decoded = try JSONDecoder().decode(MemberSet.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, MemberSet.currentSchemaVersion)
        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.name, "いつもの飲み会")
        XCTAssertEqual(decoded.roundingUnit, .fiveHundred)
        XCTAssertEqual(decoded.groups.map(\.id), [groupID])
        XCTAssertEqual(decoded.createdAt, createdAt)
        XCTAssertEqual(decoded, memberSet)
    }

    func testCompositionPreview_JoinsGroupNameCountAndRoundingUnit() {
        let memberSet = MemberSet(
            name: "いつもの飲み会",
            roundingUnit: .hundred,
            groups: [
                AttendeeGroupDraft(name: "部長", countText: "1", mode: .fixed, fixedAmountText: "10000"),
                AttendeeGroupDraft(name: "一般", countText: "4", mode: .ratio, ratioText: "1.0")
            ]
        )

        XCTAssertEqual(memberSet.compositionPreview, "部長 1 / 一般 4 · 100円")
    }
}
