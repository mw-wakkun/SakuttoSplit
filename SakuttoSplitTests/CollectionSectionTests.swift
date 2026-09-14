//
//  CollectionSectionTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import XCTest
@testable import SakuttoSplit

final class CollectionSectionTests: XCTestCase {

    func testUnpaidShareButton_IsEnabled_MatchesFlag() {
        XCTAssertTrue(UnpaidShareButton(shareText: Self.unpaidReceipt, isEnabled: true).isEnabled)
        XCTAssertFalse(UnpaidShareButton(shareText: "", isEnabled: false).isEnabled)
    }

    func testShareResultButton_StaysEnabledOnlyWhenValidationNil() {
        XCTAssertTrue(ShareResultButton(shareText: Self.mainReceipt, isEnabled: true).isEnabled)
        XCTAssertFalse(ShareResultButton(shareText: Self.mainReceipt, isEnabled: false).isEnabled)
    }

    private static let mainReceipt = """
    本日のお会計
    総額  35,000円
    ----------------
    部長  1人 10,000円
    一般  1人 6,200円
    ----------------
    不足  200円
    PayPay等で送金をお願いします
    """

    private static let unpaidReceipt = """
    未払いのお願い
    総額  35,000円
    ----------------
    一般 1  1人 6,200円
    一般 3  1人 6,200円
    ----------------
    PayPay等で送金をお願いします
    """
}
