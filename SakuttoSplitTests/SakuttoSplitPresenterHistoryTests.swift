//
//  SakuttoSplitPresenterHistoryTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import XCTest
@testable import SakuttoSplit

@MainActor
final class SakuttoSplitPresenterHistoryTests: XCTestCase {

    func testDidEnterBackground_TwiceWithSameIDs_KeepsHistoryCountOneAndUpdatesPaidKeys() {
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: store
        )
        presenter.didChangeTotalAmount("35000")
        let staffID = presenter.viewState.groups[1].id
        let paidID = CollectionSeatID(groupID: staffID, index: 0)

        presenter.didEnterBackground()
        XCTAssertEqual(store.billHistory.count, 1)
        let historyID = store.billHistory[0].id

        presenter.didTapToggleCollectionSeat(id: paidID)
        presenter.didEnterBackground()

        XCTAssertEqual(store.billHistory.count, 1)
        XCTAssertEqual(store.billHistory[0].id, historyID)
        XCTAssertEqual(store.billHistory[0].snapshot.paidSeatKeys, [paidID.rawValue])
        XCTAssertEqual(store.lastBill?.paidSeatKeys, [paidID.rawValue])
    }

    func testDidTapSettleComplete_ThenNewBill_AppendsSecondHistoryEntry() {
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: store
        )
        presenter.didChangeTotalAmount("35000")
        let firstIDs = presenter.viewState.groups.map(\.id)

        presenter.didTapSettleComplete()
        XCTAssertEqual(store.billHistory.count, 1)
        XCTAssertEqual(store.billHistory[0].snapshot.groups.map(\.id), firstIDs)

        presenter.didChangeTotalAmount("20000")
        presenter.didEnterBackground()

        XCTAssertEqual(store.billHistory.count, 2)
        XCTAssertNotEqual(store.billHistory[0].snapshot.groups.map(\.id), firstIDs)
        XCTAssertEqual(store.billHistory[1].snapshot.groups.map(\.id), firstIDs)
    }

    func testDidTapRestoreHistory_RestoresTotalAndPaid_CalculatesOnce() throws {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        let staffID = presenter.viewState.groups[1].id
        let paidID = CollectionSeatID(groupID: staffID, index: 1)
        presenter.didTapToggleCollectionSeat(id: paidID)
        presenter.didTapSettleComplete()
        let entryID = try XCTUnwrap(store.billHistory.first).id
        let callsBefore = spy.calculateCallCount

        presenter.didTapRestoreHistory(id: entryID)

        XCTAssertEqual(spy.calculateCallCount, callsBefore + 1)
        XCTAssertEqual(presenter.viewState.totalAmountText, "35000")
        XCTAssertTrue(presenter.collectionState.seats.contains { $0.id == paidID && $0.isPaid })
        XCTAssertEqual(store.lastBill?.paidSeatKeys, [paidID.rawValue])
        XCTAssertEqual(store.lastBill?.totalAmountText, "35000")
        XCTAssertFalse(presenter.sessionChrome.isHistorySheetPresented)
    }

    func testDidTapRestoreHistory_UnknownID_DoesNotRecalculate() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        presenter.didTapSettleComplete()
        presenter.didChangeTotalAmount("8888")
        let before = presenter.viewState
        let lastBillBefore = store.lastBill
        let callsBefore = spy.calculateCallCount

        presenter.didTapRestoreHistory(id: UUID())

        XCTAssertEqual(spy.calculateCallCount, callsBefore)
        XCTAssertEqual(presenter.viewState, before)
        XCTAssertEqual(store.lastBill, lastBillBefore)
        XCTAssertEqual(store.billHistory.count, 1)
    }

    func testDidTapStartHistoryComposition_UnknownID_DoesNotRecalculate() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        presenter.didTapSettleComplete()
        presenter.didChangeTotalAmount("8888")
        let before = presenter.viewState
        let callsBefore = spy.calculateCallCount

        presenter.didTapStartHistoryComposition(id: UUID())

        XCTAssertEqual(spy.calculateCallCount, callsBefore)
        XCTAssertEqual(presenter.viewState, before)
    }

    func testDidTapStartHistoryComposition_ThenChangeTotal_DiscardsUndo() throws {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        presenter.didTapSettleComplete()
        let entryID = try XCTUnwrap(store.billHistory.first).id
        presenter.didChangeTotalAmount("8888")
        presenter.didTapStartHistoryComposition(id: entryID)
        XCTAssertEqual(presenter.viewState.totalAmountText, "")

        presenter.didChangeTotalAmount("1")
        let afterEdit = presenter.viewState
        let callsAfterEdit = spy.calculateCallCount

        presenter.didTapUndoHistoryComposition()

        XCTAssertEqual(spy.calculateCallCount, callsAfterEdit)
        XCTAssertEqual(presenter.viewState, afterEdit)
        XCTAssertEqual(presenter.viewState.totalAmountText, "1")
    }

    func testDidTapUndoHistoryComposition_WhenNoUndo_DoesNotRecalculate() {
        let spy = CalculatingSpyInteractor()
        let presenter = SakuttoSplitPresenter(
            interactor: spy,
            sessionStore: InMemoryBillSessionStore()
        )
        presenter.didChangeTotalAmount("35000")
        let before = presenter.viewState
        let callsBefore = spy.calculateCallCount

        presenter.didTapUndoHistoryComposition()

        XCTAssertEqual(spy.calculateCallCount, callsBefore)
        XCTAssertEqual(presenter.viewState, before)
    }

    func testDidTapDeleteHistory_UnknownID_KeepsEntries() throws {
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: store
        )
        presenter.didChangeTotalAmount("35000")
        presenter.didTapSettleComplete()
        let entryID = try XCTUnwrap(store.billHistory.first).id

        presenter.didTapDeleteHistory(id: UUID())

        XCTAssertEqual(store.billHistory.map(\.id), [entryID])
        XCTAssertEqual(presenter.sessionChrome.history.map(\.id), [entryID])
    }

    func testDidTapStartHistoryComposition_ClearsTotalAndPaid_CalculatesOnce() throws {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        presenter.didChangeRoundingUnit(.thousand)
        let groups = presenter.viewState.groups
        presenter.didTapSettleComplete()
        let entryID = try XCTUnwrap(store.billHistory.first).id
        presenter.didChangeTotalAmount("99999")
        let callsBefore = spy.calculateCallCount

        presenter.didTapStartHistoryComposition(id: entryID)

        XCTAssertEqual(spy.calculateCallCount, callsBefore + 1)
        XCTAssertEqual(presenter.viewState.totalAmountText, "")
        XCTAssertEqual(presenter.viewState.roundingUnit, .thousand)
        XCTAssertEqual(presenter.viewState.groups.map(\.id), groups.map(\.id))
        XCTAssertTrue(presenter.collectionState.seats.isEmpty)
        XCTAssertEqual(presenter.viewState.validationIssue, .emptyTotalAmount)
    }

    func testDidTapUndoHistoryComposition_RestoresPreviousInput() throws {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        presenter.didTapSettleComplete()
        let entryID = try XCTUnwrap(store.billHistory.first).id
        presenter.didChangeTotalAmount("8888")
        presenter.didChangeRoundingUnit(.one)
        let groupsBefore = presenter.viewState.groups
        let callsBefore = spy.calculateCallCount

        presenter.didTapStartHistoryComposition(id: entryID)
        presenter.didTapUndoHistoryComposition()

        XCTAssertEqual(spy.calculateCallCount, callsBefore + 2)
        XCTAssertEqual(presenter.viewState.totalAmountText, "8888")
        XCTAssertEqual(presenter.viewState.roundingUnit, .one)
        XCTAssertEqual(presenter.viewState.groups.map(\.id), groupsBefore.map(\.id))
    }

    func testDidTapDeleteHistory_RemovesEntry_KeepsLastBill() throws {
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: store
        )
        presenter.didChangeTotalAmount("35000")
        presenter.didTapSettleComplete()
        let entryID = try XCTUnwrap(store.billHistory.first).id
        XCTAssertNotNil(store.lastBill)

        presenter.didTapDeleteHistory(id: entryID)

        XCTAssertTrue(store.billHistory.isEmpty)
        XCTAssertNotNil(store.lastBill)
        XCTAssertEqual(store.lastBill?.totalAmountText, "35000")
        XCTAssertTrue(presenter.sessionChrome.history.isEmpty)
        XCTAssertTrue(presenter.sessionChrome.hasLastBill)
    }

    func testSaveLastBill_SixDifferentIDColumns_KeepsFiveDropsOldest() {
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: store
        )
        var oldestGroupIDs: [UUID]?
        for index in 0..<6 {
            presenter.didChangeTotalAmount("35000")
            if index == 0 {
                oldestGroupIDs = presenter.viewState.groups.map(\.id)
            }
            presenter.didTapSettleComplete()
        }

        XCTAssertEqual(store.billHistory.count, 5)
        XCTAssertNotEqual(
            store.billHistory.last?.snapshot.groups.map(\.id),
            oldestGroupIDs
        )
    }

    func testClearLastBill_DoesNotClearHistory() {
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: store
        )
        presenter.didChangeTotalAmount("35000")
        presenter.didEnterBackground()
        XCTAssertEqual(store.billHistory.count, 1)

        store.clearLastBill()

        XCTAssertNil(store.lastBill)
        XCTAssertEqual(store.billHistory.count, 1)
    }

    func testDidTapOpenAndCloseHistorySheet() {
        let presenter = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: InMemoryBillSessionStore()
        )

        presenter.didTapOpenHistorySheet()
        XCTAssertTrue(presenter.sessionChrome.isHistorySheetPresented)

        presenter.didTapCloseHistorySheet()
        XCTAssertFalse(presenter.sessionChrome.isHistorySheetPresented)
    }
}
