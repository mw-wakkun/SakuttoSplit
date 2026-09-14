//
//  AttendeeGroupDraftTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import XCTest
@testable import SakuttoSplit

final class AttendeeGroupDraftTests: XCTestCase {

    func testToDomain_PreservesIDAndName() {
        let id = UUID()
        let draft = AttendeeGroupDraft(
            id: id,
            name: "部長",
            countText: "2",
            isFixed: true,
            fixedAmountText: "10000",
            ratioText: "1.5"
        )

        let domain = draft.toDomain()

        XCTAssertEqual(domain.id, id)
        XCTAssertEqual(domain.name, "部長")
        XCTAssertEqual(domain.count, 2)
        XCTAssertEqual(domain.mode, .fixed)
        XCTAssertEqual(domain.fixedAmount, 10000)
        XCTAssertEqual(domain.ratio, Decimal(1.5))
    }

    func testToDomain_InvalidCountAndAmount_BecomeZero() {
        let draft = AttendeeGroupDraft(
            name: "一般",
            countText: "abc",
            isFixed: false,
            fixedAmountText: "xyz",
            ratioText: "1.0"
        )

        let domain = draft.toDomain()

        XCTAssertEqual(domain.count, 0)
        XCTAssertEqual(domain.fixedAmount, 0)
        XCTAssertEqual(domain.mode, .ratio)
        XCTAssertEqual(domain.ratio, 1)
    }

    func testToDomain_EmptyRatioText_BecomesZero() {
        let draft = AttendeeGroupDraft(name: "全員", countText: "4", ratioText: "")
        XCTAssertEqual(draft.toDomain().ratio, 0)
    }
}
