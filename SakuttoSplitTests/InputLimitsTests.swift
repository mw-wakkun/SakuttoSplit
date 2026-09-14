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

    func testSanitizedCountText_AllowsEmptyAndClampsAt999() {
        XCTAssertEqual(InputLimits.sanitizedCountText(""), "")
        XCTAssertEqual(InputLimits.sanitizedCountText("0"), "0")
        XCTAssertEqual(InputLimits.sanitizedCountText("12a3"), "123")
        XCTAssertEqual(InputLimits.sanitizedCountText("1000"), "999")
    }

    func testSanitizedRatioText_KeepsOneDot() {
        XCTAssertEqual(InputLimits.sanitizedRatioText("1.2.5"), "1.25")
        XCTAssertEqual(InputLimits.sanitizedRatioText("."), ".")
    }
}
