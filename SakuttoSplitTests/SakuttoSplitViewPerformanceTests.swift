//
//  SakuttoSplitViewPerformanceTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI
import XCTest
@testable import SakuttoSplit

/// Equatable な子 View と結果 identity の契約
final class SakuttoSplitViewPerformanceTests: XCTestCase {

    func testAdBannerView_IsEquatableByAdUnitID() {
        XCTAssertEqual(AdBannerView(adUnitID: "ca-app-pub-test/1"), AdBannerView(adUnitID: "ca-app-pub-test/1"))
        XCTAssertNotEqual(AdBannerView(adUnitID: "ca-app-pub-test/1"), AdBannerView(adUnitID: "ca-app-pub-test/2"))
    }

    func testResultRow_IsEquatableByResult() {
        let id = UUID()
        let result = GroupCalculationResult(groupID: id, name: "一般", amountPerPerson: 5000, total: 10000)
        XCTAssertEqual(ResultRow(result: result), ResultRow(result: result))
        XCTAssertNotEqual(
            ResultRow(result: result),
            ResultRow(
                result: GroupCalculationResult(groupID: id, name: "一般", amountPerPerson: 4000, total: 8000)
            )
        )
    }

    func testDifferenceRow_IsEquatableByDifference() {
        XCTAssertEqual(DifferenceRow(difference: 100), DifferenceRow(difference: 100))
        XCTAssertNotEqual(DifferenceRow(difference: 100), DifferenceRow(difference: -100))
    }

    func testShareResultButton_IsEquatableByShareTextAndEnabled() {
        XCTAssertEqual(
            ShareResultButton(shareText: "a", isEnabled: true),
            ShareResultButton(shareText: "a", isEnabled: true)
        )
        XCTAssertNotEqual(
            ShareResultButton(shareText: "a", isEnabled: true),
            ShareResultButton(shareText: "b", isEnabled: true)
        )
        XCTAssertNotEqual(
            ShareResultButton(shareText: "a", isEnabled: true),
            ShareResultButton(shareText: "a", isEnabled: false)
        )
    }

    func testGroupCalculationResult_IdentityIsGroupID_NotName() {
        let first = UUID()
        let second = UUID()
        let a = GroupCalculationResult(groupID: first, name: "一般", amountPerPerson: 1, total: 1)
        let b = GroupCalculationResult(groupID: second, name: "一般", amountPerPerson: 1, total: 1)

        XCTAssertEqual(a.id, first)
        XCTAssertEqual(b.id, second)
        XCTAssertNotEqual(a.id, b.id)
    }
}
