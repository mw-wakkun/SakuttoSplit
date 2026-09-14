//
//  YenFormattingTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import XCTest
@testable import SakuttoSplit

final class YenFormattingTests: XCTestCase {

    func testGrouped_InsertsGroupingSeparator_WithoutSignOrFraction() {
        XCTAssertEqual(YenFormatting.grouped(0), "0")
        XCTAssertEqual(YenFormatting.grouped(6), "6")
        XCTAssertEqual(YenFormatting.grouped(6200), "6,200")
        XCTAssertEqual(YenFormatting.grouped(10000), "10,000")
        XCTAssertEqual(YenFormatting.grouped(35000), "35,000")
    }

    func testGroupedFromDigitText_ParsesIntegerString() {
        XCTAssertEqual(YenFormatting.grouped(fromDigitText: "0"), "0")
        XCTAssertEqual(YenFormatting.grouped(fromDigitText: "35000"), "35,000")
        XCTAssertEqual(YenFormatting.grouped(fromDigitText: ""), "0")
    }
}
