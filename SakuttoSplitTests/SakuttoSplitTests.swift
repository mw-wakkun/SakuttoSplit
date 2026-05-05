//
//  SakuttoSplitTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import XCTest
// アプリ本体のコードをテスト側から読み込めるようにする魔法のキーワード
@testable import SakuttoSplit

final class SplitBillInteractorTests: XCTestCase {

    var interactor: SakuttoSplitInteractor!

    // MARK: - Setup
    
    // 各テストが実行される「直前」に毎回呼ばれる準備処理
    override func setUpWithError() throws {
        try super.setUpWithError()
        interactor = SakuttoSplitInteractor() // 新しい計算職人を準備
    }

    // 各テストが実行された「直後」に毎回呼ばれる片付け処理
    override func tearDownWithError() throws {
        interactor = nil
        try super.tearDownWithError()
    }

    // MARK: - Tests
    
    /// テスト1: 割り勘の基本（固定額なし、端数なし）が正しく計算できるか
    func testCalculateBill_BasicSplit() throws {
        // 1. 準備 (Arrange)
        let groups = [
            AttendeeGroup(name: "全員", countText: "4", isFixed: false, ratioText: "1.0")
        ]
        
        // 2. 実行 (Act)
        // 20,000円を4人で均等割り（100円単位）
        let result = interactor.calculateBill(totalAmountText: "20000", roundingUnit: 100, groups: groups)
        
        // 3. 検証 (Assert)
        XCTAssertEqual(result.results.count, 1, "結果のグループ数は1つであるべき")
        XCTAssertEqual(result.results[0].amountPerPerson, 5000, "1人あたりの金額は5000円であるべき")
        XCTAssertEqual(result.collectedTotal, 20000, "集金合計は20000円であるべき")
        XCTAssertEqual(result.difference, 0, "過不足金は0円であるべき")
    }

    /// テスト2: 固定額と割合の混合（端数あり、不足金発生）が正しく計算できるか
    func testCalculateBill_WithFixedAmountAndShortage() throws {
        // 1. 準備 (Arrange)
        let groups = [
            AttendeeGroup(name: "部長", countText: "1", isFixed: true, fixedAmountText: "10000"),
            AttendeeGroup(name: "一般", countText: "4", isFixed: false, ratioText: "1.0")
        ]
        
        // 2. 実行 (Act)
        // 35,000円のお会計
        let result = interactor.calculateBill(totalAmountText: "35000", roundingUnit: 100, groups: groups)
        
        // 3. 検証 (Assert)
        // 部長は固定の10,000円
        XCTAssertEqual(result.results[0].amountPerPerson, 10000)
        
        // 一般は (35000 - 10000) / 4人 = 6250円。100円単位で切り捨てるので 6200円
        XCTAssertEqual(result.results[1].amountPerPerson, 6200)
        
        // 集金合計は 10000 + (6200 * 4) = 34800円
        XCTAssertEqual(result.collectedTotal, 34800)
        
        // 不足金は 34800 - 35000 = -200円 になるはず
        XCTAssertEqual(result.difference, -200)
    }
}
