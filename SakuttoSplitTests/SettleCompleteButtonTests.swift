//
//  SettleCompleteButtonTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import XCTest
@testable import SakuttoSplit

final class SettleCompleteButtonTests: XCTestCase {

    func testIsEnabled_MatchesValidationIssueNil() {
        XCTAssertTrue(SettleCompleteButton(validationIssue: nil, action: {}).isEnabled)
        XCTAssertFalse(SettleCompleteButton(validationIssue: .emptyTotalAmount, action: {}).isEnabled)
        XCTAssertFalse(SettleCompleteButton(validationIssue: .noGroups, action: {}).isEnabled)
        XCTAssertFalse(SettleCompleteButton(validationIssue: .fixedAmountExceedsTotal, action: {}).isEnabled)
    }
}
