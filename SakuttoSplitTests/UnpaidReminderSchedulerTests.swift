//
//  UnpaidReminderSchedulerTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import XCTest
@testable import SakuttoSplit

/// 本物の UNUserNotificationCenter は叩かない。予約規則は Spy で固定する
final class SpyUnpaidReminderScheduler: UnpaidReminderScheduling {
    var authorizationStatus: UnpaidReminderAuthorizationStatus = .notDetermined
    var requestAuthorizationResult = true
    private(set) var requestAuthorizationCallCount = 0
    private(set) var syncUnpaidCounts: [Int] = []
    private(set) var scheduleCallCount = 0
    private(set) var cancelCallCount = 0
    private(set) var scheduledUnpaidCount: Int?

    func requestAuthorizationIfNeeded() async -> Bool {
        requestAuthorizationCallCount += 1
        if requestAuthorizationResult {
            authorizationStatus = .authorized
        } else {
            authorizationStatus = .denied
        }
        return requestAuthorizationResult
    }

    func sync(unpaidCount: Int) {
        syncUnpaidCounts.append(unpaidCount)
        guard authorizationStatus == .authorized else {
            if scheduledUnpaidCount != nil {
                cancelCallCount += 1
                scheduledUnpaidCount = nil
            }
            return
        }
        if unpaidCount == 0 {
            cancelCallCount += 1
            scheduledUnpaidCount = nil
            return
        }
        scheduleCallCount += 1
        scheduledUnpaidCount = unpaidCount
    }
}

final class UnpaidReminderSchedulerTests: XCTestCase {

    func testNullScheduler_SyncIsNoOp() {
        let scheduler = NullUnpaidReminderScheduler()

        scheduler.sync(unpaidCount: 3)
        scheduler.sync(unpaidCount: 0)

        XCTAssertEqual(scheduler.authorizationStatus, .notDetermined)
    }

    func testNullScheduler_RequestAuthorization_ReturnsFalse() async {
        let granted = await NullUnpaidReminderScheduler().requestAuthorizationIfNeeded()

        XCTAssertFalse(granted)
    }

    func testRequestIdentifier_IsFixed() {
        XCTAssertEqual(
            UnpaidReminderScheduler.requestIdentifier,
            "io.github.mw-wakkun.SakuttoSplit.unpaidReminder"
        )
    }
}

@MainActor
final class UnpaidReminderPresenterSyncTests: XCTestCase {

    func testSetCollectionState_WhenNotAuthorized_DoesNotSchedule() {
        let scheduler = SpyUnpaidReminderScheduler()
        let setup = makeValidPresenter(scheduler: scheduler)
        XCTAssertEqual(scheduler.scheduleCallCount, 0)

        setup.presenter.didTapToggleCollectionSeat(id: setup.presenter.collectionState.seats[0].id)

        XCTAssertEqual(scheduler.scheduleCallCount, 0)
        XCTAssertNil(scheduler.scheduledUnpaidCount)
        XCTAssertFalse(scheduler.syncUnpaidCounts.isEmpty)
    }

    func testSetCollectionState_WhenAuthorized_SchedulesUnpaidCount() {
        let scheduler = SpyUnpaidReminderScheduler()
        scheduler.authorizationStatus = .authorized
        let setup = makeValidPresenter(scheduler: scheduler)
        let unpaidAfterInit = setup.presenter.collectionState.unpaidSeats.count
        XCTAssertEqual(scheduler.scheduledUnpaidCount, unpaidAfterInit)

        setup.presenter.didTapToggleCollectionSeat(id: setup.presenter.collectionState.seats[0].id)

        XCTAssertEqual(
            scheduler.scheduledUnpaidCount,
            setup.presenter.collectionState.unpaidSeats.count
        )
        XCTAssertGreaterThanOrEqual(scheduler.scheduleCallCount, 2)
    }

    func testSetCollectionState_WhenUnpaidBecomesZero_Cancels() {
        let scheduler = SpyUnpaidReminderScheduler()
        scheduler.authorizationStatus = .authorized
        let setup = makeValidPresenter(scheduler: scheduler)
        let presenter = setup.presenter
        let spy = setup.spy
        let callsBefore = spy.calculateCallCount
        let cancelBefore = scheduler.cancelCallCount

        for seat in presenter.collectionState.seats {
            presenter.didTapToggleCollectionSeat(id: seat.id)
        }

        XCTAssertTrue(presenter.collectionState.unpaidSeats.isEmpty)
        XCTAssertEqual(scheduler.scheduledUnpaidCount, nil)
        XCTAssertEqual(scheduler.cancelCallCount, cancelBefore + 1)
        XCTAssertEqual(spy.calculateCallCount, callsBefore)
    }

    func testDidTapSettleComplete_CancelsReminder() {
        let scheduler = SpyUnpaidReminderScheduler()
        scheduler.authorizationStatus = .authorized
        let setup = makeValidPresenter(scheduler: scheduler)
        let cancelBefore = scheduler.cancelCallCount

        setup.presenter.didTapSettleComplete()

        XCTAssertGreaterThanOrEqual(scheduler.cancelCallCount, cancelBefore + 1)
        XCTAssertNil(scheduler.scheduledUnpaidCount)
        XCTAssertTrue(setup.presenter.collectionState.seats.isEmpty)
    }

    func testDidCompleteAuthorization_Granted_SchedulesCurrentUnpaid() {
        let scheduler = SpyUnpaidReminderScheduler()
        let setup = makeValidPresenter(scheduler: scheduler)
        scheduler.authorizationStatus = .authorized

        setup.presenter.didCompleteUnpaidReminderAuthorization(granted: true)

        XCTAssertEqual(
            scheduler.scheduledUnpaidCount,
            setup.presenter.collectionState.unpaidSeats.count
        )
    }

    func testDidCompleteAuthorization_Denied_Cancels() {
        let scheduler = SpyUnpaidReminderScheduler()
        scheduler.authorizationStatus = .authorized
        let setup = makeValidPresenter(scheduler: scheduler)
        XCTAssertNotNil(scheduler.scheduledUnpaidCount)

        setup.presenter.didCompleteUnpaidReminderAuthorization(granted: false)

        XCTAssertNil(scheduler.scheduledUnpaidCount)
    }

    func testNeedsUnpaidReminderPrompt_AfterMainShareWithUnpaid() {
        let scheduler = SpyUnpaidReminderScheduler()
        let setup = makeValidPresenter(scheduler: scheduler)

        XCTAssertFalse(setup.presenter.sessionChrome.needsUnpaidReminderPrompt)

        setup.presenter.didPerformMainShare()

        XCTAssertTrue(setup.presenter.sessionChrome.needsUnpaidReminderPrompt)
    }

    func testNeedsUnpaidReminderPrompt_WhenAllPaid_IsFalse() {
        let scheduler = SpyUnpaidReminderScheduler()
        let setup = makeValidPresenter(scheduler: scheduler)
        for seat in setup.presenter.collectionState.seats {
            setup.presenter.didTapToggleCollectionSeat(id: seat.id)
        }

        setup.presenter.didPerformMainShare()

        XCTAssertFalse(setup.presenter.sessionChrome.needsUnpaidReminderPrompt)
    }

    func testDidConsumeUnpaidReminderPrompt_DoesNotReturnOnLaterShare() {
        let scheduler = SpyUnpaidReminderScheduler()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: store,
            reminderScheduler: scheduler
        )
        presenter.didChangeTotalAmount("35000")
        presenter.didPerformMainShare()
        XCTAssertTrue(presenter.sessionChrome.needsUnpaidReminderPrompt)

        presenter.didConsumeUnpaidReminderPrompt()
        presenter.didPerformMainShare()

        XCTAssertFalse(presenter.sessionChrome.needsUnpaidReminderPrompt)
        XCTAssertTrue(store.didPromptUnpaidReminder)

        let restarted = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: store,
            reminderScheduler: scheduler
        )
        restarted.didChangeTotalAmount("35000")
        restarted.didPerformMainShare()
        XCTAssertFalse(restarted.sessionChrome.needsUnpaidReminderPrompt)
    }

    private func makeValidPresenter(
        scheduler: SpyUnpaidReminderScheduler
    ) -> (presenter: SakuttoSplitPresenter, spy: CalculatingSpyInteractor, store: InMemoryBillSessionStore) {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(
            interactor: spy,
            sessionStore: store,
            reminderScheduler: scheduler
        )
        presenter.didChangeTotalAmount("35000")
        return (presenter, spy, store)
    }
}
