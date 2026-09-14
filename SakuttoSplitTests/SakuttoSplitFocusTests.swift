//
//  SakuttoSplitFocusTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import XCTest
@testable import SakuttoSplit

final class SakuttoSplitFocusTests: XCTestCase {

    func testNext_FromTotalAmount_GoesToFirstGroupName() {
        let groups = Self.defaultGroups

        XCTAssertEqual(
            SakuttoSplitFocus.totalAmount.next(in: groups),
            .groupName(groups[0].id)
        )
    }

    func testNext_FromTotalAmount_WhenNoGroups_Dismisses() {
        XCTAssertNil(SakuttoSplitFocus.totalAmount.next(in: []))
    }

    func testNext_FromGroupName_GoesToCount() {
        let groups = Self.defaultGroups

        XCTAssertEqual(
            SakuttoSplitFocus.groupName(groups[0].id).next(in: groups),
            .groupCount(groups[0].id)
        )
    }

    func testNext_FromCount_WhenExpanded_GoesToPaymentField() {
        let groups = Self.defaultGroups

        XCTAssertEqual(
            SakuttoSplitFocus.groupCount(groups[0].id).next(in: groups),
            .fixedAmount(groups[0].id)
        )
        XCTAssertEqual(
            SakuttoSplitFocus.groupCount(groups[1].id).next(in: groups),
            .ratio(groups[1].id)
        )
    }

    func testNext_FromCount_WhenCollapsed_GoesToNextGroupName() {
        let groups = Self.defaultGroups

        XCTAssertEqual(
            SakuttoSplitFocus.groupCount(groups[0].id).next(in: groups, isPaymentExpanded: { _ in false }),
            .groupName(groups[1].id)
        )
    }

    func testNext_FromPaymentField_GoesToNextGroupName_ThenDismisses() {
        let groups = Self.defaultGroups

        XCTAssertEqual(
            SakuttoSplitFocus.fixedAmount(groups[0].id).next(in: groups),
            .groupName(groups[1].id)
        )
        XCTAssertNil(SakuttoSplitFocus.ratio(groups[1].id).next(in: groups))
    }
}

private extension SakuttoSplitFocusTests {
    static var defaultGroups: [AttendeeGroupDraft] {
        [
            AttendeeGroupDraft(name: "部長", countText: "1", mode: .fixed, fixedAmountText: "10000"),
            AttendeeGroupDraft(name: "一般", countText: "4", mode: .ratio, ratioText: "1.0")
        ]
    }
}
