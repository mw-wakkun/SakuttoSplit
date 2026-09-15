//
//  InputLimitsTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import XCTest
@testable import SakuttoSplit

final class InputLimitsTests: XCTestCase {

    func testSanitizedTotalAmountText_StripsNonDigitsAndCapsAt8() {
        XCTAssertEqual(InputLimits.sanitizedTotalAmountText("12a3456789"), "12345678")
        XCTAssertEqual(InputLimits.sanitizedTotalAmountText(""), "")
    }

    func testSanitizedFixedAmountText_StripsNonDigitsAndCapsAt8() {
        XCTAssertEqual(InputLimits.sanitizedFixedAmountText("8a000"), "8000")
        XCTAssertEqual(InputLimits.sanitizedFixedAmountText("12a3456789"), "12345678")
        XCTAssertEqual(InputLimits.sanitizedFixedAmountText(""), "")
    }

    /// 人数の正本は 1...999。空・0・非数字は "1"、桁除去後にクランプする
    func testSanitizedCountText_ClampsToOneThrough999() {
        XCTAssertEqual(InputLimits.sanitizedCountText(""), "1")
        XCTAssertEqual(InputLimits.sanitizedCountText("0"), "1")
        XCTAssertEqual(InputLimits.sanitizedCountText("abc"), "1")
        XCTAssertEqual(InputLimits.sanitizedCountText("1000"), "999")
        XCTAssertEqual(InputLimits.sanitizedCountText("12a3"), "123")
    }

    func testSanitizedRatioText_KeepsOneDot() {
        XCTAssertEqual(InputLimits.sanitizedRatioText("1.2.5"), "1.25")
        XCTAssertEqual(InputLimits.sanitizedRatioText("."), ".")
    }

    /// 整数 3 桁・小数 2 桁。空と "." はそのまま。400 桁の 9 も 999 に切る
    func testSanitizedRatioText_CapsIntegerAndFractionDigits() {
        XCTAssertEqual(InputLimits.sanitizedRatioText("1.25"), "1.25")
        XCTAssertEqual(InputLimits.sanitizedRatioText("1.2.5"), "1.25")
        XCTAssertEqual(InputLimits.sanitizedRatioText("."), ".")
        XCTAssertEqual(InputLimits.sanitizedRatioText(""), "")
        XCTAssertEqual(InputLimits.sanitizedRatioText("1234.567"), "123.56")
        XCTAssertEqual(InputLimits.sanitizedRatioText("9999"), "999")
        XCTAssertEqual(InputLimits.sanitizedRatioText(String(repeating: "9", count: 400)), "999")
    }

    func testCollectionExpandMaxCount_Is20() {
        XCTAssertEqual(InputLimits.collectionExpandMaxCount, 20)
        XCTAssertEqual(InputLimits.groupMaxCount, 20)
    }
}
