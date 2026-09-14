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
}
