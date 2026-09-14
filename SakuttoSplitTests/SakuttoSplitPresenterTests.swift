//
//  SakuttoSplitPresenterTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import XCTest
@testable import SakuttoSplit

@MainActor
final class SakuttoSplitPresenterTests: XCTestCase {

    func testInit_CalculatesOnce_WithDefaultGroups() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)

        XCTAssertEqual(spy.calculateCallCount, 1)
        XCTAssertEqual(presenter.viewState.groups.count, 2)
        XCTAssertEqual(presenter.viewState.groups[0].name, "部長")
        XCTAssertEqual(presenter.viewState.groups[1].name, "一般")
        XCTAssertEqual(presenter.viewState.roundingUnit, .hundred)
        XCTAssertEqual(presenter.viewState.totalAmountText, "")
        XCTAssertEqual(presenter.viewState.validationIssue, .emptyTotalAmount)
        XCTAssertFalse(presenter.viewState.isShareEnabled)
    }

    func testDidChangeTotalAmount_SanitizesDigitsAndMaxLength_CalculatesOnce() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)
        let callsAfterInit = spy.calculateCallCount

        presenter.didChangeTotalAmount("12a3456789")

        XCTAssertEqual(presenter.viewState.totalAmountText, "12345678")
        XCTAssertEqual(spy.calculateCallCount, callsAfterInit + 1)
        XCTAssertEqual(spy.lastInput?.totalAmount, 12345678)
    }

    func testDidChangeTotalAmount_SameSanitizedValue_DoesNotRecalculate() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)

        presenter.didChangeTotalAmount("35000")
        let callsAfterFirstChange = spy.calculateCallCount

        presenter.didChangeTotalAmount("35000")
        presenter.didChangeTotalAmount("35000abc")

        XCTAssertEqual(presenter.viewState.totalAmountText, "35000")
        XCTAssertEqual(spy.calculateCallCount, callsAfterFirstChange)
    }

    func testDidChangeRoundingUnit_CalculatesOnce() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)
        let callsAfterInit = spy.calculateCallCount

        presenter.didChangeRoundingUnit(.thousand)

        XCTAssertEqual(presenter.viewState.roundingUnit, .thousand)
        XCTAssertEqual(spy.calculateCallCount, callsAfterInit + 1)
        XCTAssertEqual(spy.lastInput?.roundingUnit, .thousand)
    }

    func testDidChangeGroupCount_ClampsAbove999_AndStripsNonDigits() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)
        let groupID = presenter.viewState.groups[1].id
        let callsAfterInit = spy.calculateCallCount

        presenter.didChangeGroupCount(id: groupID, countText: "10a00")

        XCTAssertEqual(presenter.viewState.groups[1].countText, "999")
        XCTAssertEqual(spy.calculateCallCount, callsAfterInit + 1)
        XCTAssertEqual(spy.lastInput?.groups[1].count, 999)
    }

    /// 空・0・非数字は "1" に正規化し、計算入力の人数も 1
    func testDidChangeGroupCount_EmptyZeroAndNonNumeric_BecomeOne() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)
        let groupID = presenter.viewState.groups[1].id

        presenter.didChangeGroupCount(id: groupID, countText: "")
        XCTAssertEqual(presenter.viewState.groups[1].countText, "1")
        XCTAssertEqual(spy.lastInput?.groups[1].count, 1)

        presenter.didChangeGroupCount(id: groupID, countText: "3")
        presenter.didChangeGroupCount(id: groupID, countText: "0")
        XCTAssertEqual(presenter.viewState.groups[1].countText, "1")
        XCTAssertEqual(spy.lastInput?.groups[1].count, 1)

        presenter.didChangeGroupCount(id: groupID, countText: "3")
        presenter.didChangeGroupCount(id: groupID, countText: "abc")
        XCTAssertEqual(presenter.viewState.groups[1].countText, "1")
        XCTAssertEqual(spy.lastInput?.groups[1].count, 1)
    }

    /// "" → "1" のあと再び "" でも表示は "1" のままなので再計算しない
    func testDidChangeGroupCount_EmptyAfterNormalizedToOne_DoesNotRecalculate() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)
        let groupID = presenter.viewState.groups[1].id

        presenter.didChangeGroupCount(id: groupID, countText: "")
        XCTAssertEqual(presenter.viewState.groups[1].countText, "1")
        let callsAfterNormalize = spy.calculateCallCount

        presenter.didChangeGroupCount(id: groupID, countText: "")
        XCTAssertEqual(presenter.viewState.groups[1].countText, "1")
        XCTAssertEqual(spy.calculateCallCount, callsAfterNormalize)
    }

    func testDidChangePaymentMode_AndFixedAmount_EachCalculateOnce() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)
        let groupID = presenter.viewState.groups[1].id
        let callsAfterInit = spy.calculateCallCount

        presenter.didChangePaymentMode(id: groupID, mode: .fixed)
        presenter.didChangeFixedAmount(id: groupID, text: "8a000")

        XCTAssertEqual(presenter.viewState.groups[1].mode, .fixed)
        XCTAssertEqual(presenter.viewState.groups[1].fixedAmountText, "8000")
        XCTAssertEqual(spy.calculateCallCount, callsAfterInit + 2)
    }

    func testDidChangeRatio_KeepsSingleDecimalPoint() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)
        let groupID = presenter.viewState.groups[1].id

        presenter.didChangeRatio(id: groupID, text: "1.2.5a")

        XCTAssertEqual(presenter.viewState.groups[1].ratioText, "1.25")
    }

    func testDidTapAddGroup_AppendsDefaultRatioGroup_CalculatesOnce() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)
        let callsAfterInit = spy.calculateCallCount

        presenter.didTapAddGroup()

        XCTAssertEqual(presenter.viewState.groups.count, 3)
        XCTAssertEqual(presenter.viewState.groups[2].name, "新規グループ3")
        XCTAssertEqual(presenter.viewState.groups[2].mode, .ratio)
        XCTAssertEqual(presenter.viewState.groups[2].countText, "1")
        XCTAssertEqual(presenter.viewState.groups[2].ratioText, "1.0")
        XCTAssertEqual(spy.calculateCallCount, callsAfterInit + 1)
    }

    func testDidTapRemoveGroup_RemovesMatchingGroup_CalculatesOnce() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)
        let removedID = presenter.viewState.groups[0].id
        let remainingID = presenter.viewState.groups[1].id
        let callsAfterInit = spy.calculateCallCount

        presenter.didTapRemoveGroup(id: removedID)

        XCTAssertEqual(presenter.viewState.groups.map(\.id), [remainingID])
        XCTAssertEqual(spy.calculateCallCount, callsAfterInit + 1)
    }

    func testDidTapRemoveGroup_UnknownID_DoesNotRecalculate() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)
        let callsAfterInit = spy.calculateCallCount

        presenter.didTapRemoveGroup(id: UUID())

        XCTAssertEqual(presenter.viewState.groups.count, 2)
        XCTAssertEqual(spy.calculateCallCount, callsAfterInit)
    }

    func testShareText_MatchesPreviousViewFormat() {
        let presenter = SakuttoSplitPresenter(interactor: SakuttoSplitInteractor())

        presenter.didChangeTotalAmount("35000")

        let expected = Self.expectedShareTextForDefaultGroupsTotal35000
        XCTAssertEqual(presenter.viewState.shareText, expected)
        XCTAssertNil(presenter.viewState.validationIssue)
        XCTAssertTrue(presenter.viewState.isShareEnabled)
    }

    /// シェア文は ViewState の正本。総額変更と同じ代入で更新され、計算は増えない
    func testViewState_ShareTextUpdatesWhenTotalAmountChanges() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)
        let callsAfterInit = spy.calculateCallCount

        presenter.didChangeTotalAmount("35000")

        XCTAssertEqual(spy.calculateCallCount, callsAfterInit + 1)
        XCTAssertEqual(
            presenter.viewState.shareText,
            Self.expectedShareTextForDefaultGroupsTotal35000
        )
    }

    func testViewState_UpdatesResultsInTheSameAssignmentAsInput() {
        let spy = CalculatingSpyInteractor()
        spy.stub = BillCalculationOutput(
            results: [
                GroupCalculationResult(groupID: UUID(), name: "stub", amountPerPerson: 100, total: 100)
            ],
            collectedTotal: 100,
            difference: -50
        )
        let presenter = SakuttoSplitPresenter(interactor: spy)

        presenter.didChangeTotalAmount("1000")

        XCTAssertEqual(presenter.viewState.totalAmountText, "1000")
        XCTAssertEqual(presenter.viewState.results.first?.name, "stub")
        XCTAssertEqual(presenter.viewState.difference, -50)
    }

    /// 人数 +/- は Intent 1 回 = 計算 1 回
    func testDidChangeGroupCount_Increment_CalculatesExactlyOnce() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)
        let groupID = presenter.viewState.groups[1].id
        let current = Int(presenter.viewState.groups[1].countText) ?? 1
        let callsAfterInit = spy.calculateCallCount

        presenter.didChangeGroupCount(id: groupID, countText: "\(current + 1)")

        XCTAssertEqual(presenter.viewState.groups[1].countText, "\(current + 1)")
        XCTAssertEqual(spy.calculateCallCount, callsAfterInit + 1)
    }

    /// 同名グループでも結果は groupID で区別できる
    func testDuplicateGroupNames_ResultsAreIdentifiedByGroupID() {
        let presenter = SakuttoSplitPresenter(interactor: SakuttoSplitInteractor())
        let firstID = presenter.viewState.groups[0].id
        let secondID = presenter.viewState.groups[1].id

        presenter.didChangeGroupName(id: firstID, name: "一般")
        presenter.didChangePaymentMode(id: firstID, mode: .ratio)
        presenter.didChangeRatio(id: firstID, text: "1.0")
        presenter.didChangeGroupCount(id: firstID, countText: "2")
        presenter.didChangeGroupCount(id: secondID, countText: "2")
        presenter.didChangeTotalAmount("20000")

        XCTAssertEqual(presenter.viewState.results.map(\.name), ["一般", "一般"])
        XCTAssertEqual(presenter.viewState.results.map(\.groupID), [firstID, secondID])
        XCTAssertEqual(presenter.viewState.results.map(\.id), [firstID, secondID])
        XCTAssertEqual(Set(presenter.viewState.results.map(\.id)).count, 2)
    }

    func testValidation_EmptyTotalAmount_DisablesShare() {
        let presenter = SakuttoSplitPresenter(interactor: SakuttoSplitInteractor())

        XCTAssertEqual(presenter.viewState.validationIssue, .emptyTotalAmount)
        XCTAssertFalse(presenter.viewState.isShareEnabled)

        presenter.didChangeTotalAmount("35000")

        XCTAssertNil(presenter.viewState.validationIssue)
        XCTAssertTrue(presenter.viewState.isShareEnabled)
    }

    func testValidation_ShortageDoesNotDisableShare() {
        let presenter = SakuttoSplitPresenter(interactor: SakuttoSplitInteractor())

        presenter.didChangeTotalAmount("35000")

        XCTAssertEqual(presenter.viewState.difference, -200)
        XCTAssertNil(presenter.viewState.validationIssue)
        XCTAssertTrue(presenter.viewState.isShareEnabled)
    }

    func testValidation_NoGroups_DisablesShare() {
        let presenter = SakuttoSplitPresenter(interactor: SakuttoSplitInteractor())
        presenter.didChangeTotalAmount("35000")
        let firstID = presenter.viewState.groups[0].id
        let secondID = presenter.viewState.groups[1].id

        presenter.didTapRemoveGroup(id: firstID)
        presenter.didTapRemoveGroup(id: secondID)

        XCTAssertTrue(presenter.viewState.groups.isEmpty)
        XCTAssertEqual(presenter.viewState.validationIssue, .noGroups)
        XCTAssertFalse(presenter.viewState.isShareEnabled)
    }

    func testValidation_NoGroupsTakesPrecedenceOverEmptyTotal() {
        let presenter = SakuttoSplitPresenter(interactor: SakuttoSplitInteractor())
        let firstID = presenter.viewState.groups[0].id
        let secondID = presenter.viewState.groups[1].id

        presenter.didTapRemoveGroup(id: firstID)
        presenter.didTapRemoveGroup(id: secondID)

        XCTAssertEqual(presenter.viewState.totalAmountText, "")
        XCTAssertEqual(presenter.viewState.validationIssue, .noGroups)
        XCTAssertFalse(presenter.viewState.isShareEnabled)
    }

    func testValidation_FixedAmountExceedsTotal_DisablesShare_KeepsCalculation() {
        let presenter = SakuttoSplitPresenter(interactor: SakuttoSplitInteractor())

        presenter.didChangeTotalAmount("5000")

        XCTAssertEqual(presenter.viewState.validationIssue, .fixedAmountExceedsTotal)
        XCTAssertFalse(presenter.viewState.isShareEnabled)
        XCTAssertEqual(presenter.viewState.results[0].amountPerPerson, 10000)
        XCTAssertEqual(presenter.viewState.results[1].amountPerPerson, 0)
        XCTAssertEqual(presenter.viewState.difference, 5000)
    }

    private static let expectedShareTextForDefaultGroupsTotal35000 = """
    🍻 本日のお会計 🍻
    総額: 35000 円
    ----------------
    部長: 1人 10000円
    一般: 1人 6200円
    ----------------
    ⚠️ 不足金: 200円
    ※PayPay等で送金をお願いします！
    """
}

private final class CalculatingSpyInteractor: SakuttoSplitInteractorProtocol {
    private(set) var calculateCallCount = 0
    private(set) var lastInput: BillCalculationInput?
    var stub: BillCalculationOutput?
    private let real = SakuttoSplitInteractor()

    func calculateBill(_ input: BillCalculationInput) -> BillCalculationOutput {
        calculateCallCount += 1
        lastInput = input
        if let stub {
            return stub
        }
        return real.calculateBill(input)
    }
}
