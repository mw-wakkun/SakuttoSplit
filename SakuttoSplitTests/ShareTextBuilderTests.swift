//
//  ShareTextBuilderTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import XCTest
@testable import SakuttoSplit

final class ShareTextBuilderTests: XCTestCase {

    func testBuild_MainShareText_MatchesExistingJapaneseCopy() {
        let managerID = UUID()
        let staffID = UUID()
        let text = ShareTextBuilder.build(
            totalAmountText: "35000",
            results: [
                GroupCalculationResult(groupID: managerID, name: "部長", amountPerPerson: 10000, total: 10000),
                GroupCalculationResult(groupID: staffID, name: "一般", amountPerPerson: 6200, total: 24800)
            ],
            difference: -200
        )

        XCTAssertEqual(text, Self.expectedMainShareTextForDefaultGroupsTotal35000)
    }

    func testBuildUnpaid_IncludesOnlyGivenUnpaidSeats() {
        let groupID = UUID()
        let seats = [
            CollectionSeat(
                id: CollectionSeatID(groupID: groupID, index: 1),
                groupName: "一般",
                displayNumber: 2,
                amountPerPerson: 6200,
                isPaid: false
            ),
            CollectionSeat(
                id: CollectionSeatID(groupID: groupID, index: 3),
                groupName: "一般",
                displayNumber: 4,
                amountPerPerson: 6200,
                isPaid: false
            )
        ]

        let text = ShareTextBuilder.buildUnpaid(totalAmountText: "35000", unpaidSeats: seats)

        XCTAssertEqual(
            text,
            """
            🍻 未払いのお願い 🍻
            総額: 35000 円
            ----------------
            一般 2: 1人 6200円
            一般 4: 1人 6200円
            ----------------
            ※PayPay等で送金をお願いします！
            """
        )
    }

    func testBuildUnpaid_WhenEmpty_ReturnsEmptyString() {
        XCTAssertEqual(
            ShareTextBuilder.buildUnpaid(totalAmountText: "35000", unpaidSeats: []),
            ""
        )
    }

    private static let expectedMainShareTextForDefaultGroupsTotal35000 = """
    🍻 本日のお会計 🍻
    総額: 35000 円
    ----------------
    部長: 1人 10000円
    一般: 1人 6200円
    ----------------
    ⚠️ 不足金: 200円
    ※PayPay等で送金をお願いします！
    """
}
