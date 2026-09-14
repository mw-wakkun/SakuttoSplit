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
        XCTAssertTrue(UnpaidShareButton(shareText: "🍻 未払いのお願い 🍻", isEnabled: true).isEnabled)
        XCTAssertFalse(UnpaidShareButton(shareText: "", isEnabled: false).isEnabled)
    }

    func testShareResultButton_StaysEnabledOnlyWhenValidationNil() {
        XCTAssertTrue(ShareResultButton(shareText: "🍻 本日のお会計 🍻", isEnabled: true).isEnabled)
        XCTAssertFalse(ShareResultButton(shareText: "🍻 本日のお会計 🍻", isEnabled: false).isEnabled)
    }
}
