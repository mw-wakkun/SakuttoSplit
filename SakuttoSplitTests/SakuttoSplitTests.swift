//
//  SakuttoSplitTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import XCTest
@testable import SakuttoSplit

/// フェーズ 0: 現行 Interactor の計算仕様を固定する。
/// プロダクトコードは変更せず、リファクタ前後で期待値が変わらないことを保証する。
final class SplitBillInteractorTests: XCTestCase {

    var interactor: SakuttoSplitInteractor!

    // MARK: - Setup

    override func setUpWithError() throws {
        try super.setUpWithError()
        interactor = SakuttoSplitInteractor()
    }

    override func tearDownWithError() throws {
        interactor = nil
        try super.tearDownWithError()
    }

    // MARK: - 既存仕様（ハッピーパス）

    /// 割り勘の基本（固定額なし、端数なし）
    func testCalculateBill_BasicSplit() throws {
        let groups = [
            AttendeeGroup(name: "全員", countText: "4", isFixed: false, ratioText: "1.0")
        ]

        let result = calculate(totalAmountText: "20000", roundingUnit: 100, groups: groups)

        XCTAssertEqual(result.results.count, 1, "結果のグループ数は1つであるべき")
        XCTAssertEqual(result.results[0].amountPerPerson, 5000, "1人あたりの金額は5000円であるべき")
        XCTAssertEqual(result.collectedTotal, 20000, "集金合計は20000円であるべき")
        XCTAssertEqual(result.difference, 0, "過不足金は0円であるべき")
    }

    /// 固定額と割合の混合（端数あり、不足金発生）
    func testCalculateBill_WithFixedAmountAndShortage() throws {
        let groups = [
            AttendeeGroup(name: "部長", countText: "1", isFixed: true, fixedAmountText: "10000"),
            AttendeeGroup(name: "一般", countText: "4", isFixed: false, ratioText: "1.0")
        ]

        let result = calculate(totalAmountText: "35000", roundingUnit: 100, groups: groups)

        XCTAssertEqual(result.results[0].amountPerPerson, 10000)
        // 一般は (35000 - 10000) / 4人 = 6250円。100円単位で切り捨てるので 6200円
        XCTAssertEqual(result.results[1].amountPerPerson, 6200)
        // 集金合計は 10000 + (6200 * 4) = 34800円
        XCTAssertEqual(result.collectedTotal, 34800)
        // 不足金は 34800 - 35000 = -200円
        XCTAssertEqual(result.difference, -200)
    }

    // MARK: - 総額のパース（空文字・非数値は 0）

    func testCalculateBill_EmptyTotalAmount_IsTreatedAsZero() {
        let groups = [
            AttendeeGroup(name: "全員", countText: "4", isFixed: false, ratioText: "1.0")
        ]

        let result = calculate(totalAmountText: "", roundingUnit: 100, groups: groups)

        XCTAssertEqual(result.results.count, 1)
        XCTAssertEqual(result.results[0].amountPerPerson, 0)
        XCTAssertEqual(result.results[0].total, 0)
        XCTAssertEqual(result.collectedTotal, 0)
        XCTAssertEqual(result.difference, 0)
    }

    func testCalculateBill_NonNumericTotalAmount_IsTreatedAsZero() {
        let groups = [
            AttendeeGroup(name: "全員", countText: "4", isFixed: false, ratioText: "1.0")
        ]

        let result = calculate(totalAmountText: "abc", roundingUnit: 100, groups: groups)

        XCTAssertEqual(result.results.count, 1)
        XCTAssertEqual(result.results[0].amountPerPerson, 0)
        XCTAssertEqual(result.collectedTotal, 0)
        XCTAssertEqual(result.difference, 0)
    }

    // MARK: - グループ 0 件

    func testCalculateBill_NoGroups() {
        let result = calculate(totalAmountText: "20000", roundingUnit: 100, groups: [])

        XCTAssertTrue(result.results.isEmpty)
        XCTAssertEqual(result.collectedTotal, 0)
        XCTAssertEqual(result.difference, -20000)
    }

    // MARK: - 全員固定額

    func testCalculateBill_AllFixed_ExactMatch() {
        let groups = [
            AttendeeGroup(name: "部長", countText: "1", isFixed: true, fixedAmountText: "10000"),
            AttendeeGroup(name: "課長", countText: "2", isFixed: true, fixedAmountText: "5000")
        ]

        let result = calculate(totalAmountText: "20000", roundingUnit: 100, groups: groups)

        XCTAssertEqual(result.results.count, 2)
        XCTAssertEqual(result.results[0].amountPerPerson, 10000)
        XCTAssertEqual(result.results[0].total, 10000)
        XCTAssertEqual(result.results[1].amountPerPerson, 5000)
        XCTAssertEqual(result.results[1].total, 10000)
        XCTAssertEqual(result.collectedTotal, 20000)
        XCTAssertEqual(result.difference, 0)
    }

    func testCalculateBill_AllFixed_ExceedsTotal() {
        let groups = [
            AttendeeGroup(name: "部長", countText: "1", isFixed: true, fixedAmountText: "15000")
        ]

        let result = calculate(totalAmountText: "10000", roundingUnit: 100, groups: groups)

        XCTAssertEqual(result.results[0].amountPerPerson, 15000)
        XCTAssertEqual(result.results[0].total, 15000)
        XCTAssertEqual(result.collectedTotal, 15000)
        XCTAssertEqual(result.difference, 5000)
    }

    // MARK: - 倍率合計 0

    func testCalculateBill_RatioGroupsOnly_ZeroRatio() {
        let groups = [
            AttendeeGroup(name: "全員", countText: "4", isFixed: false, ratioText: "0")
        ]

        let result = calculate(totalAmountText: "20000", roundingUnit: 100, groups: groups)

        XCTAssertEqual(result.results[0].amountPerPerson, 0)
        XCTAssertEqual(result.results[0].total, 0)
        XCTAssertEqual(result.collectedTotal, 0)
        XCTAssertEqual(result.difference, -20000)
    }

    func testCalculateBill_RatioGroupsOnly_EmptyRatioText() {
        let groups = [
            AttendeeGroup(name: "全員", countText: "4", isFixed: false, ratioText: "")
        ]

        let result = calculate(totalAmountText: "20000", roundingUnit: 100, groups: groups)

        XCTAssertEqual(result.results[0].amountPerPerson, 0)
        XCTAssertEqual(result.results[0].total, 0)
        XCTAssertEqual(result.collectedTotal, 0)
        XCTAssertEqual(result.difference, -20000)
    }

    // MARK: - 端数単位

    func testCalculateBill_RoundingUnit1() {
        let groups = [
            AttendeeGroup(name: "全員", countText: "3", isFixed: false, ratioText: "1.0")
        ]

        let result = calculate(totalAmountText: "10000", roundingUnit: 1, groups: groups)

        // 10000 / 3 = 3333.333... → 1円単位切り捨てで 3333円
        XCTAssertEqual(result.results[0].amountPerPerson, 3333)
        XCTAssertEqual(result.collectedTotal, 9999)
        XCTAssertEqual(result.difference, -1)
    }

    func testCalculateBill_RoundingUnit10() {
        let groups = [
            AttendeeGroup(name: "全員", countText: "3", isFixed: false, ratioText: "1.0")
        ]

        let result = calculate(totalAmountText: "10000", roundingUnit: 10, groups: groups)

        // 3333.333... → 10円単位切り捨てで 3330円
        XCTAssertEqual(result.results[0].amountPerPerson, 3330)
        XCTAssertEqual(result.collectedTotal, 9990)
        XCTAssertEqual(result.difference, -10)
    }

    func testCalculateBill_RoundingUnit500() {
        let groups = [
            AttendeeGroup(name: "全員", countText: "4", isFixed: false, ratioText: "1.0")
        ]

        let result = calculate(totalAmountText: "35000", roundingUnit: 500, groups: groups)

        // 35000 / 4 = 8750 → 500円単位切り捨てで 8500円
        XCTAssertEqual(result.results[0].amountPerPerson, 8500)
        XCTAssertEqual(result.collectedTotal, 34000)
        XCTAssertEqual(result.difference, -1000)
    }

    func testCalculateBill_RoundingUnit1000() {
        let groups = [
            AttendeeGroup(name: "全員", countText: "4", isFixed: false, ratioText: "1.0")
        ]

        let result = calculate(totalAmountText: "35000", roundingUnit: 1000, groups: groups)

        // 35000 / 4 = 8750 → 1000円単位切り捨てで 8000円
        XCTAssertEqual(result.results[0].amountPerPerson, 8000)
        XCTAssertEqual(result.collectedTotal, 32000)
        XCTAssertEqual(result.difference, -3000)
    }

    // MARK: - 人数 0 / 不正文字列

    func testCalculateBill_ZeroCount_RatioGroupOnly() {
        let groups = [
            AttendeeGroup(name: "全員", countText: "0", isFixed: false, ratioText: "1.0")
        ]

        let result = calculate(totalAmountText: "20000", roundingUnit: 100, groups: groups)

        XCTAssertEqual(result.results[0].amountPerPerson, 0)
        XCTAssertEqual(result.results[0].total, 0)
        XCTAssertEqual(result.collectedTotal, 0)
        XCTAssertEqual(result.difference, -20000)
    }

    func testCalculateBill_InvalidCountText_IsTreatedAsZero() {
        let groups = [
            AttendeeGroup(name: "全員", countText: "abc", isFixed: false, ratioText: "1.0")
        ]

        let result = calculate(totalAmountText: "20000", roundingUnit: 100, groups: groups)

        XCTAssertEqual(result.results[0].amountPerPerson, 0)
        XCTAssertEqual(result.results[0].total, 0)
        XCTAssertEqual(result.collectedTotal, 0)
        XCTAssertEqual(result.difference, -20000)
    }

    func testCalculateBill_ZeroCount_WithOtherRatioGroup() {
        let groups = [
            AttendeeGroup(name: "欠席", countText: "0", isFixed: false, ratioText: "1.0"),
            AttendeeGroup(name: "出席", countText: "4", isFixed: false, ratioText: "1.0")
        ]

        let result = calculate(totalAmountText: "20000", roundingUnit: 100, groups: groups)

        // totalRatio = 0 + 4。欠席は単価 5000 × 0人 = 0、出席は 5000 × 4
        XCTAssertEqual(result.results[0].amountPerPerson, 5000)
        XCTAssertEqual(result.results[0].total, 0)
        XCTAssertEqual(result.results[1].amountPerPerson, 5000)
        XCTAssertEqual(result.results[1].total, 20000)
        XCTAssertEqual(result.collectedTotal, 20000)
        XCTAssertEqual(result.difference, 0)
    }

    // MARK: - 同名グループ

    func testCalculateBill_DuplicateGroupNames_AreKeptAsSeparateResults() {
        let groups = [
            AttendeeGroup(name: "一般", countText: "2", isFixed: false, ratioText: "1.0"),
            AttendeeGroup(name: "一般", countText: "2", isFixed: false, ratioText: "1.0")
        ]

        let result = calculate(totalAmountText: "20000", roundingUnit: 100, groups: groups)

        // 現行仕様では結果に groupID がなく、名前と配列順でのみ区別する
        XCTAssertEqual(result.results.count, 2)
        XCTAssertEqual(result.results[0].name, "一般")
        XCTAssertEqual(result.results[1].name, "一般")
        XCTAssertEqual(result.results[0].amountPerPerson, 5000)
        XCTAssertEqual(result.results[1].amountPerPerson, 5000)
        XCTAssertEqual(result.results[0].total, 10000)
        XCTAssertEqual(result.results[1].total, 10000)
        XCTAssertEqual(result.collectedTotal, 20000)
        XCTAssertEqual(result.difference, 0)
    }

    // MARK: - 固定額 × 人数が総額を超過

    func testCalculateBill_FixedAmountTimesCountExceedsTotal_RatioGroupGetsZero() {
        let groups = [
            AttendeeGroup(name: "部長", countText: "2", isFixed: true, fixedAmountText: "10000"),
            AttendeeGroup(name: "一般", countText: "4", isFixed: false, ratioText: "1.0")
        ]

        let result = calculate(totalAmountText: "15000", roundingUnit: 100, groups: groups)

        // 固定合計 20000 が総額 15000 を超えるため残金は 0。按分グループは 0 円
        XCTAssertEqual(result.results[0].amountPerPerson, 10000)
        XCTAssertEqual(result.results[0].total, 20000)
        XCTAssertEqual(result.results[1].amountPerPerson, 0)
        XCTAssertEqual(result.results[1].total, 0)
        XCTAssertEqual(result.collectedTotal, 20000)
        XCTAssertEqual(result.difference, 5000)
    }

    // MARK: - Helpers

    private func calculate(
        totalAmountText: String,
        roundingUnit: Int,
        groups: [AttendeeGroup]
    ) -> (results: [SakuttoSplitInteractor.CalculationResult], collectedTotal: Int, difference: Int) {
        interactor.calculateBill(
            totalAmountText: totalAmountText,
            roundingUnit: roundingUnit,
            groups: groups
        )
    }
}
