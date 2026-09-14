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
        XCTAssertEqual(presenter.viewState.groups[0].mode, .fixed)
        XCTAssertEqual(presenter.viewState.groups[1].name, "一般")
        XCTAssertEqual(presenter.viewState.groups[1].mode, .ratio)
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
        XCTAssertFalse(expected.contains("🍻"))
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

    func testDidTapSettleComplete_WhenEmptyTotal_DoesNotChangeState() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)
        let before = presenter.viewState
        let callsAfterInit = spy.calculateCallCount

        presenter.didTapSettleComplete()

        XCTAssertEqual(presenter.viewState, before)
        XCTAssertEqual(spy.calculateCallCount, callsAfterInit)
    }

    func testDidTapSettleComplete_WhenNoGroups_DoesNotChangeState() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)
        presenter.didChangeTotalAmount("35000")
        let firstID = presenter.viewState.groups[0].id
        let secondID = presenter.viewState.groups[1].id
        presenter.didTapRemoveGroup(id: firstID)
        presenter.didTapRemoveGroup(id: secondID)
        let before = presenter.viewState
        let callsBeforeSettle = spy.calculateCallCount

        presenter.didTapSettleComplete()

        XCTAssertEqual(presenter.viewState.validationIssue, .noGroups)
        XCTAssertEqual(presenter.viewState, before)
        XCTAssertEqual(spy.calculateCallCount, callsBeforeSettle)
    }

    func testDidTapSettleComplete_WhenFixedAmountExceedsTotal_DoesNotChangeState() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(interactor: spy)
        presenter.didChangeTotalAmount("5000")
        let before = presenter.viewState
        let callsBeforeSettle = spy.calculateCallCount

        presenter.didTapSettleComplete()

        XCTAssertEqual(presenter.viewState.validationIssue, .fixedAmountExceedsTotal)
        XCTAssertEqual(presenter.viewState, before)
        XCTAssertEqual(spy.calculateCallCount, callsBeforeSettle)
    }

    func testDidTapSettleComplete_WhenValid_ResetsToCalculatedInitial() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        presenter.didChangeRoundingUnit(.thousand)
        let callsBeforeSettle = spy.calculateCallCount

        presenter.didTapSettleComplete()

        XCTAssertEqual(spy.calculateCallCount, callsBeforeSettle + 1)
        Self.assertMatchesCalculatedInitial(presenter.viewState)
    }

    func testDidTapSettleComplete_WhenValid_PersistsLastBillBeforeReset() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        presenter.didChangeRoundingUnit(.thousand)
        let groupsBefore = presenter.viewState.groups
        let callsBeforeSettle = spy.calculateCallCount

        presenter.didTapSettleComplete()

        XCTAssertEqual(spy.calculateCallCount, callsBeforeSettle + 1)
        Self.assertMatchesCalculatedInitial(presenter.viewState)
        XCTAssertEqual(store.lastBill?.totalAmountText, "35000")
        XCTAssertEqual(store.lastBill?.roundingUnit, .thousand)
        XCTAssertEqual(store.lastBill?.groups.map(\.id), groupsBefore.map(\.id))
        XCTAssertEqual(store.lastBill?.groups.map(\.name), groupsBefore.map(\.name))
        XCTAssertEqual(store.lastBill?.groups.map(\.countText), groupsBefore.map(\.countText))
        XCTAssertTrue(presenter.sessionChrome.hasLastBill)
        XCTAssertFalse(presenter.needsRestoreConfirmation)
    }

    func testDidTapSettleComplete_WhenEmptyTotal_DoesNotChangeExistingLastBill() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let existing = BillSnapshot(
            totalAmountText: "12000",
            roundingUnit: .hundred,
            groups: [AttendeeGroupDraft(name: "残す")]
        )
        store.saveLastBill(existing)
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        let before = presenter.viewState
        let callsAfterInit = spy.calculateCallCount

        presenter.didTapSettleComplete()

        XCTAssertEqual(presenter.viewState, before)
        XCTAssertEqual(spy.calculateCallCount, callsAfterInit)
        XCTAssertEqual(store.lastBill, existing)
    }

    func testDidChangeTotalAmount_DoesNotPersistLastBill() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)

        presenter.didChangeTotalAmount("35000")

        XCTAssertNil(presenter.viewState.validationIssue)
        XCTAssertNil(store.lastBill)
        XCTAssertEqual(store.saveLastBillCallCount, 0)
    }

    func testDidEnterBackground_WhenValid_SavesLastBillWithoutRecalculating() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        let groupsBefore = presenter.viewState.groups
        let callsBeforeBackground = spy.calculateCallCount

        presenter.didEnterBackground()

        XCTAssertEqual(spy.calculateCallCount, callsBeforeBackground)
        XCTAssertEqual(presenter.viewState.totalAmountText, "35000")
        XCTAssertEqual(store.lastBill?.totalAmountText, "35000")
        XCTAssertEqual(store.lastBill?.groups.map(\.id), groupsBefore.map(\.id))
    }

    func testDidEnterBackground_WhenInvalid_DoesNotOverwriteLastBill() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let existing = BillSnapshot(
            totalAmountText: "12000",
            roundingUnit: .hundred,
            groups: [AttendeeGroupDraft(name: "残す")]
        )
        store.saveLastBill(existing)
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        XCTAssertEqual(presenter.viewState.validationIssue, .emptyTotalAmount)
        let callsAfterInit = spy.calculateCallCount

        presenter.didEnterBackground()

        XCTAssertEqual(spy.calculateCallCount, callsAfterInit)
        XCTAssertEqual(store.lastBill, existing)
        XCTAssertTrue(presenter.sessionChrome.hasLastBill)
    }

    func testInit_WithExistingLastBill_StartsAtInitial_AndShowsRestore() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let groupID = UUID()
        store.saveLastBill(
            BillSnapshot(
                totalAmountText: "35000",
                roundingUnit: .thousand,
                groups: [
                    AttendeeGroupDraft(
                        id: groupID,
                        name: "部長",
                        countText: "1",
                        mode: .fixed,
                        fixedAmountText: "10000"
                    )
                ]
            )
        )

        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)

        XCTAssertEqual(presenter.viewState.totalAmountText, "")
        XCTAssertEqual(presenter.viewState.validationIssue, .emptyTotalAmount)
        XCTAssertFalse(presenter.viewState.isShareEnabled)
        XCTAssertTrue(presenter.sessionChrome.hasLastBill)
        XCTAssertFalse(presenter.needsRestoreConfirmation)
        XCTAssertEqual(store.lastBill?.groups.map(\.id), [groupID])
        XCTAssertEqual(presenter.sessionChrome.lastBillPreview?.totalAmountText, "35000")
        XCTAssertEqual(presenter.sessionChrome.lastBillPreview?.seatCount, 1)
        XCTAssertEqual(presenter.sessionChrome.lastBillPreview?.unpaidCount, 1)
    }

    func testDidTapRestoreLastBill_RestoresInputCalculatesOnce_AndEnablesShare() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        let groupsBefore = presenter.viewState.groups
        presenter.didTapSettleComplete()
        let callsAfterSettle = spy.calculateCallCount

        presenter.didTapRestoreLastBill()

        XCTAssertEqual(spy.calculateCallCount, callsAfterSettle + 1)
        XCTAssertEqual(presenter.viewState.totalAmountText, "35000")
        XCTAssertEqual(presenter.viewState.groups.map(\.id), groupsBefore.map(\.id))
        XCTAssertEqual(presenter.viewState.groups.map(\.name), groupsBefore.map(\.name))
        XCTAssertEqual(presenter.viewState.groups.map(\.countText), groupsBefore.map(\.countText))
        XCTAssertNil(presenter.viewState.validationIssue)
        XCTAssertTrue(presenter.viewState.isShareEnabled)
        XCTAssertFalse(presenter.needsRestoreConfirmation)
        XCTAssertEqual(
            presenter.viewState.shareText,
            Self.expectedShareTextForDefaultGroupsTotal35000
        )
    }

    func testDidTapRestoreLastBill_WhenNoLastBill_DoesNotRecalculate() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        let callsAfterInit = spy.calculateCallCount
        let before = presenter.viewState

        presenter.didTapRestoreLastBill()

        XCTAssertEqual(spy.calculateCallCount, callsAfterInit)
        XCTAssertEqual(presenter.viewState, before)
        XCTAssertFalse(presenter.sessionChrome.hasLastBill)
    }

    func testDidTapRestoreLastBill_WhenAlreadyRestored_DoesNotRecalculate() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        presenter.didTapSettleComplete()
        presenter.didTapRestoreLastBill()
        let callsAfterRestore = spy.calculateCallCount

        presenter.didTapRestoreLastBill()

        XCTAssertEqual(spy.calculateCallCount, callsAfterRestore)
    }

    func testNeedsRestoreConfirmation_WhenEditedAwayFromInitial_IsTrue() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        presenter.didTapSettleComplete()
        XCTAssertFalse(presenter.needsRestoreConfirmation)

        presenter.didChangeTotalAmount("1000")

        XCTAssertTrue(presenter.needsRestoreConfirmation)
        XCTAssertTrue(presenter.sessionChrome.hasLastBill)
    }

    func testDidEnterBackground_WhenValid_SetsHasLastBill() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        XCTAssertFalse(presenter.sessionChrome.hasLastBill)
        presenter.didChangeTotalAmount("35000")

        presenter.didEnterBackground()

        XCTAssertTrue(presenter.sessionChrome.hasLastBill)
        XCTAssertEqual(store.lastBill?.totalAmountText, "35000")
    }

    func testLastBillPreview_WhenNoLastBill_IsNil() {
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: store
        )

        XCTAssertFalse(presenter.sessionChrome.hasLastBill)
        XCTAssertNil(presenter.sessionChrome.lastBillPreview)
    }

    func testLastBillPreview_DefaultGroupsWithTwoPaidSeats_UnpaidThreeOfFive() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let managerID = UUID()
        let staffID = UUID()
        let paidKeys = [
            CollectionSeatID(groupID: managerID, index: 0).rawValue,
            CollectionSeatID(groupID: staffID, index: 1).rawValue
        ]
        store.saveLastBill(
            BillSnapshot(
                totalAmountText: "35000",
                roundingUnit: .hundred,
                groups: [
                    AttendeeGroupDraft(
                        id: managerID,
                        name: "部長",
                        countText: "1",
                        mode: .fixed,
                        fixedAmountText: "10000"
                    ),
                    AttendeeGroupDraft(
                        id: staffID,
                        name: "一般",
                        countText: "4",
                        mode: .ratio,
                        ratioText: "1.0"
                    )
                ],
                paidSeatKeys: paidKeys + [CollectionSeatID(groupID: UUID(), index: 99).rawValue]
            )
        )

        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)

        XCTAssertEqual(presenter.sessionChrome.lastBillPreview?.totalAmountText, "35000")
        XCTAssertEqual(presenter.sessionChrome.lastBillPreview?.seatCount, 5)
        XCTAssertEqual(presenter.sessionChrome.lastBillPreview?.unpaidCount, 3)
        XCTAssertEqual(presenter.viewState.totalAmountText, "")
    }

    func testDidTapSaveMemberSet_WhenSlotAvailable_PersistsWithoutRecalculating() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeRoundingUnit(.thousand)
        let groups = presenter.viewState.groups
        let callsBeforeSave = spy.calculateCallCount

        presenter.didTapSaveMemberSet(name: "いつもの飲み会")

        XCTAssertEqual(spy.calculateCallCount, callsBeforeSave)
        XCTAssertEqual(store.memberSets.count, 1)
        XCTAssertEqual(store.memberSets[0].name, "いつもの飲み会")
        XCTAssertEqual(store.memberSets[0].roundingUnit, .thousand)
        XCTAssertEqual(store.memberSets[0].groups.map(\.id), groups.map(\.id))
        XCTAssertEqual(presenter.sessionChrome.memberSets.count, 1)
        XCTAssertFalse(presenter.sessionChrome.hasEmptyMemberSetSlot)
        XCTAssertEqual(presenter.viewState.totalAmountText, "")
    }

    func testDidTapSaveMemberSet_WhenNameBlank_UsesDefaultName() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)

        presenter.didTapSaveMemberSet(name: "  ")

        XCTAssertEqual(store.memberSets.map(\.name), ["セット1"])
    }

    func testDidTapSaveMemberSet_WhenNoGroups_DoesNotWrite() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didTapRemoveGroup(id: presenter.viewState.groups[0].id)
        presenter.didTapRemoveGroup(id: presenter.viewState.groups[0].id)

        presenter.didTapSaveMemberSet(name: "いつもの")

        XCTAssertTrue(store.memberSets.isEmpty)
        XCTAssertTrue(presenter.sessionChrome.memberSets.isEmpty)
    }

    func testDidTapSaveMemberSet_WhenNoEmptySlot_DoesNotWriteSecond() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didTapSaveMemberSet(name: "1件目")

        presenter.didTapSaveMemberSet(name: "2件目")

        XCTAssertEqual(store.memberSets.map(\.name), ["1件目"])
        XCTAssertEqual(presenter.sessionChrome.memberSets.count, 1)
    }

    func testDidTapApplyMemberSet_KeepsTotal_ReplacesGroupsAndRounding_CalculatesOnce() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        presenter.didChangeRoundingUnit(.thousand)
        let savedGroups = presenter.viewState.groups
        presenter.didTapSaveMemberSet(name: "いつもの")
        presenter.didTapAddGroup()
        presenter.didChangeRoundingUnit(.one)
        let callsBeforeApply = spy.calculateCallCount
        let setID = store.memberSets[0].id

        presenter.didTapApplyMemberSet(id: setID)

        XCTAssertEqual(spy.calculateCallCount, callsBeforeApply + 1)
        XCTAssertEqual(presenter.viewState.totalAmountText, "35000")
        XCTAssertEqual(presenter.viewState.roundingUnit, .thousand)
        XCTAssertEqual(presenter.viewState.groups.map(\.id), savedGroups.map(\.id))
        XCTAssertEqual(presenter.viewState.groups.map(\.name), savedGroups.map(\.name))
        XCTAssertEqual(presenter.viewState.groups.count, 2)
        XCTAssertNil(presenter.viewState.validationIssue)
        XCTAssertTrue(presenter.viewState.isShareEnabled)
        XCTAssertFalse(presenter.sessionChrome.isMemberSetSheetPresented)
    }

    func testDidTapApplyMemberSet_KeepsUndo_RestoresGroupsAndRoundingWithoutChangingTotal() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        presenter.didChangeRoundingUnit(.thousand)
        let groupsBeforeApply = presenter.viewState.groups
        presenter.didTapSaveMemberSet(name: "いつもの")
        presenter.didTapAddGroup()
        presenter.didChangeRoundingUnit(.one)
        let groupsAfterEdit = presenter.viewState.groups
        let callsBeforeApply = spy.calculateCallCount
        let setID = store.memberSets[0].id

        presenter.didTapApplyMemberSet(id: setID)

        XCTAssertEqual(spy.calculateCallCount, callsBeforeApply + 1)
        XCTAssertEqual(presenter.viewState.totalAmountText, "35000")
        XCTAssertEqual(presenter.viewState.roundingUnit, .thousand)
        XCTAssertEqual(presenter.viewState.groups.map(\.id), groupsBeforeApply.map(\.id))
        XCTAssertEqual(presenter.viewState.groups.count, 2)

        let callsBeforeUndo = spy.calculateCallCount
        presenter.didTapUndoMemberSetApply()

        XCTAssertEqual(spy.calculateCallCount, callsBeforeUndo + 1)
        XCTAssertEqual(presenter.viewState.totalAmountText, "35000")
        XCTAssertEqual(presenter.viewState.roundingUnit, .one)
        XCTAssertEqual(presenter.viewState.groups.map(\.id), groupsAfterEdit.map(\.id))
        XCTAssertEqual(presenter.viewState.groups.map(\.name), groupsAfterEdit.map(\.name))
        XCTAssertEqual(presenter.viewState.groups.count, 3)
    }

    func testDidTapApplyMemberSet_ThenChangeTotal_DiscardsUndo() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        presenter.didTapSaveMemberSet(name: "いつもの")
        presenter.didTapAddGroup()
        let groupsAfterEdit = presenter.viewState.groups
        presenter.didTapApplyMemberSet(id: store.memberSets[0].id)
        XCTAssertEqual(presenter.viewState.groups.count, 2)

        presenter.didChangeTotalAmount("40000")
        let callsAfterTotalChange = spy.calculateCallCount
        let groupsAfterApply = presenter.viewState.groups

        presenter.didTapUndoMemberSetApply()

        XCTAssertEqual(spy.calculateCallCount, callsAfterTotalChange)
        XCTAssertEqual(presenter.viewState.totalAmountText, "40000")
        XCTAssertEqual(presenter.viewState.groups.map(\.id), groupsAfterApply.map(\.id))
        XCTAssertNotEqual(presenter.viewState.groups.map(\.id), groupsAfterEdit.map(\.id))
    }

    func testDidTapUndoMemberSetApply_WhenNoUndo_DoesNotRecalculate() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        let before = presenter.viewState
        let callsBefore = spy.calculateCallCount

        presenter.didTapUndoMemberSetApply()

        XCTAssertEqual(spy.calculateCallCount, callsBefore)
        XCTAssertEqual(presenter.viewState, before)
    }

    func testDidTapDeleteMemberSet_RemovesSet_KeepsSlotCount() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didTapSaveMemberSet(name: "いつもの")
        let setID = store.memberSets[0].id

        presenter.didTapDeleteMemberSet(id: setID)

        XCTAssertTrue(store.memberSets.isEmpty)
        XCTAssertTrue(presenter.sessionChrome.memberSets.isEmpty)
        XCTAssertEqual(store.slotCount, 1)
        XCTAssertEqual(presenter.sessionChrome.slotCount, 1)
        XCTAssertTrue(presenter.sessionChrome.hasEmptyMemberSetSlot)
    }

    func testInit_LoadsExistingMemberSets_WithoutApplyingThem() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let groupID = UUID()
        XCTAssertTrue(
            store.saveMemberSet(
                MemberSet(
                    name: "残す",
                    roundingUnit: .fiveHundred,
                    groups: [
                        AttendeeGroupDraft(id: groupID, name: "部長", countText: "2", mode: .fixed, fixedAmountText: "8000")
                    ]
                )
            )
        )

        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)

        XCTAssertEqual(presenter.sessionChrome.memberSets.map(\.name), ["残す"])
        XCTAssertEqual(presenter.viewState.groups.count, 2)
        XCTAssertEqual(presenter.viewState.groups[0].name, "部長")
        XCTAssertEqual(presenter.viewState.roundingUnit, .hundred)
        XCTAssertNotEqual(presenter.viewState.groups[0].id, groupID)
    }

    func testInit_BrokenSessionData_StartsAtInitialWithoutCrashing() throws {
        let suiteName = "test.sakuttosplit.broken.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(Data("not-json".utf8), forKey: BillSessionStore.lastBillKey)
        defaults.set(Data("also-broken".utf8), forKey: BillSessionStore.memberSetsKey)
        defaults.set(99, forKey: BillSessionStore.slotCountKey)
        let store = BillSessionStore(defaults: defaults)
        let spy = CalculatingSpyInteractor()

        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)

        XCTAssertEqual(presenter.viewState.totalAmountText, "")
        XCTAssertEqual(presenter.viewState.groups.count, 2)
        XCTAssertEqual(presenter.viewState.groups[0].name, "部長")
        XCTAssertEqual(presenter.viewState.roundingUnit, .hundred)
        XCTAssertFalse(presenter.sessionChrome.hasLastBill)
        XCTAssertTrue(presenter.sessionChrome.memberSets.isEmpty)
        XCTAssertEqual(presenter.sessionChrome.slotCount, 3)
        XCTAssertEqual(spy.calculateCallCount, 1)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testMemberSetSheet_OpenAndClose_DoesNotRecalculate() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        let callsAfterInit = spy.calculateCallCount

        presenter.didTapOpenMemberSetSheet()
        XCTAssertTrue(presenter.sessionChrome.isMemberSetSheetPresented)
        presenter.didTapCloseMemberSetSheet()
        XCTAssertFalse(presenter.sessionChrome.isMemberSetSheetPresented)
        XCTAssertEqual(spy.calculateCallCount, callsAfterInit)
    }

    func testDidUnlockMemberSetSlot_IncrementsOnce_ThenAllowsSecondSave() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didTapSaveMemberSet(name: "1件目")
        XCTAssertFalse(presenter.sessionChrome.hasEmptyMemberSetSlot)
        let callsBeforeUnlock = spy.calculateCallCount

        presenter.didUnlockMemberSetSlot()

        XCTAssertEqual(spy.calculateCallCount, callsBeforeUnlock)
        XCTAssertEqual(store.slotCount, 2)
        XCTAssertEqual(presenter.sessionChrome.slotCount, 2)
        XCTAssertTrue(presenter.sessionChrome.hasEmptyMemberSetSlot)
        XCTAssertTrue(presenter.sessionChrome.canUnlockMemberSetSlot)

        presenter.didTapSaveMemberSet(name: "2件目")

        XCTAssertEqual(store.memberSets.map(\.name), ["1件目", "2件目"])
        XCTAssertFalse(presenter.sessionChrome.hasEmptyMemberSetSlot)
    }

    func testDidUnlockMemberSetSlot_WhenAlreadyThree_DoesNotChange() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore(slotCount: 3)
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        XCTAssertFalse(presenter.sessionChrome.canUnlockMemberSetSlot)

        presenter.didUnlockMemberSetSlot()

        XCTAssertEqual(store.slotCount, 3)
        XCTAssertEqual(presenter.sessionChrome.slotCount, 3)
        XCTAssertFalse(presenter.sessionChrome.canUnlockMemberSetSlot)
    }

    func testDidTapSettleComplete_WhenFixedAmountExceedsTotal_DoesNotChangeExistingLastBill() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let existing = BillSnapshot(
            totalAmountText: "12000",
            roundingUnit: .hundred,
            groups: [AttendeeGroupDraft(name: "残す")]
        )
        store.saveLastBill(existing)
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("5000")
        let before = presenter.viewState
        let callsBeforeSettle = spy.calculateCallCount

        presenter.didTapSettleComplete()

        XCTAssertEqual(presenter.viewState.validationIssue, .fixedAmountExceedsTotal)
        XCTAssertEqual(presenter.viewState, before)
        XCTAssertEqual(spy.calculateCallCount, callsBeforeSettle)
        XCTAssertEqual(store.lastBill, existing)
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

    /// グループ ID はリセットで作り直されるので、起動時 Presenter と中身だけ比べる
    private static func assertMatchesCalculatedInitial(_ actual: SakuttoSplitViewState) {
        let expected = SakuttoSplitPresenter(interactor: SakuttoSplitInteractor()).viewState
        XCTAssertEqual(actual.totalAmountText, expected.totalAmountText)
        XCTAssertEqual(actual.roundingUnit, expected.roundingUnit)
        XCTAssertEqual(actual.groups.map(groupSnapshot), expected.groups.map(groupSnapshot))
        XCTAssertEqual(actual.results.map(resultSnapshot), expected.results.map(resultSnapshot))
        XCTAssertEqual(actual.difference, expected.difference)
        XCTAssertEqual(actual.shareText, expected.shareText)
        XCTAssertEqual(actual.validationIssue, expected.validationIssue)
        XCTAssertFalse(actual.isShareEnabled)
    }

    private static func groupSnapshot(_ group: AttendeeGroupDraft) -> [
        String
    ] {
        [group.name, group.countText, "\(group.mode)", group.fixedAmountText, group.ratioText]
    }

    private static func resultSnapshot(_ result: GroupCalculationResult) -> [String] {
        [result.name, "\(result.amountPerPerson)", "\(result.total)"]
    }

    private static let expectedShareTextForDefaultGroupsTotal35000 = """
    本日のお会計
    総額  35,000円
    ----------------
    部長  1人 10,000円
    一般  1人 6,200円
    ----------------
    不足  200円
    PayPay等で送金をお願いします
    """
}

final class CalculatingSpyInteractor: SakuttoSplitInteractorProtocol {
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
