//
//  SakuttoSplitInteractorSafetyTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import XCTest
@testable import SakuttoSplit

/// 倍率の非有限・桁溢れでも calculateBill が trap せず return することを固定する。
/// 金額のハッピーパスは SakuttoSplitInteractorTests を正本とし、このファイルでは変えない。
final class SakuttoSplitInteractorSafetyTests: XCTestCase {

    private var interactor: SakuttoSplitInteractorProtocol!

    override func setUpWithError() throws {
        try super.setUpWithError()
        interactor = SakuttoSplitInteractor()
    }

    override func tearDownWithError() throws {
        interactor = nil
        try super.tearDownWithError()
    }

    /// 長い 9 列は parseRatio が 0 にし、Interactor 直呼びでも trap しない
    func testCalculateBill_RatioTextThatParsesToInfinity_ReturnsZero() {
        let groups = [
            AttendeeGroupDraft(
                name: "全員",
                countText: "4",
                mode: .ratio,
                ratioText: String(repeating: "9", count: 400)
            ).toDomain()
        ]

        let result = calculate(totalAmount: 20000, roundingUnit: .hundred, groups: groups)

        XCTAssertEqual(result.results.count, 1)
        XCTAssertEqual(result.results[0].amountPerPerson, 0)
        XCTAssertEqual(result.results[0].total, 0)
        XCTAssertEqual(result.collectedTotal, 0)
        XCTAssertEqual(result.difference, -20000)
    }

    func testCalculateBill_NaNRatio_ReturnsZeroWithoutTrapping() {
        let groups = [
            AttendeeGroup(name: "全員", count: 4, mode: .ratio, ratio: Decimal.nan)
        ]

        let result = calculate(totalAmount: 20000, roundingUnit: .hundred, groups: groups)

        XCTAssertEqual(result.results.count, 1)
        XCTAssertEqual(result.results[0].amountPerPerson, 0)
        XCTAssertEqual(result.results[0].total, 0)
        XCTAssertEqual(result.collectedTotal, 0)
    }

    /// Decimal として巨大でも有限なら現行式のまま return する
    func testCalculateBill_HugeFiniteRatio_ReturnsWithoutTrapping() {
        let hugeRatio = Decimal(sign: .plus, exponent: 127, significand: 1)
        let groups = [
            AttendeeGroup(name: "全員", count: 4, mode: .ratio, ratio: hugeRatio)
        ]

        let result = calculate(totalAmount: 20000, roundingUnit: .hundred, groups: groups)

        XCTAssertEqual(result.results.count, 1)
        XCTAssertEqual(result.results[0].amountPerPerson, 5000)
        XCTAssertEqual(result.results[0].total, 20000)
        XCTAssertEqual(result.collectedTotal, 20000)
        XCTAssertEqual(result.difference, 0)
    }

    /// Double 経由の Int 変換が範囲外でも trap せず 0
    func testCalculateBill_IntConversionOverflow_ReturnsZeroWithoutTrapping() {
        let groups = [
            AttendeeGroup(name: "全員", count: 1, mode: .ratio, ratio: 1)
        ]

        let result = calculate(totalAmount: Int.max, roundingUnit: .one, groups: groups)

        XCTAssertEqual(result.results.count, 1)
        XCTAssertEqual(result.results[0].amountPerPerson, 0)
        XCTAssertEqual(result.results[0].total, 0)
    }

    private func calculate(
        totalAmount: Int,
        roundingUnit: RoundingUnit,
        groups: [AttendeeGroup]
    ) -> BillCalculationOutput {
        interactor.calculateBill(
            BillCalculationInput(
                totalAmount: totalAmount,
                roundingUnit: roundingUnit,
                groups: groups
            )
        )
    }
}
