//
//  SakuttoSplitPresenterOfferTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import XCTest
@testable import SakuttoSplit

@MainActor
final class SakuttoSplitPresenterOfferTests: XCTestCase {

    func testShowsMemberSetOffer_BeforeMainShare_IsFalse() {
        let presenter = makeValidPresenter().presenter

        XCTAssertFalse(presenter.showsMemberSetOffer)
    }

    func testShowsMemberSetOffer_AfterMainShare_IsTrue() {
        let presenter = makeValidPresenter().presenter

        presenter.didPerformMainShare()

        XCTAssertTrue(presenter.showsMemberSetOffer)
        XCTAssertTrue(presenter.sessionChrome.hasEmptyMemberSetSlot)
        XCTAssertTrue(presenter.sessionChrome.memberSets.isEmpty)
    }

    func testShowsMemberSetOffer_SecondMainShare_StaysTrue() {
        let presenter = makeValidPresenter().presenter
        presenter.didPerformMainShare()

        presenter.didPerformMainShare()

        XCTAssertTrue(presenter.showsMemberSetOffer)
    }

    func testDidPerformMainShare_WhenShareDisabled_DoesNotShowOffer() {
        let presenter = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: InMemoryBillSessionStore()
        )

        presenter.didPerformMainShare()

        XCTAssertFalse(presenter.viewState.isShareEnabled)
        XCTAssertFalse(presenter.showsMemberSetOffer)
    }

    func testShowsMemberSetOffer_WhenMemberSetExists_IsFalse() {
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: store
        )
        presenter.didChangeTotalAmount("35000")
        presenter.didTapSaveMemberSet(name: "いつもの")
        presenter.didPerformMainShare()

        XCTAssertFalse(presenter.showsMemberSetOffer)
        XCTAssertTrue(store.memberSetOfferConsumed)
    }

    func testDidDismissMemberSetOffer_HidesAndSurvivesRelaunch() {
        let store = InMemoryBillSessionStore()
        let first = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: store
        )
        first.didChangeTotalAmount("35000")
        first.didPerformMainShare()
        XCTAssertTrue(first.showsMemberSetOffer)

        first.didDismissMemberSetOffer()

        XCTAssertFalse(first.showsMemberSetOffer)
        XCTAssertTrue(store.memberSetOfferConsumed)

        let restarted = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: store
        )
        restarted.didChangeTotalAmount("35000")
        restarted.didPerformMainShare()
        XCTAssertFalse(restarted.showsMemberSetOffer)
    }

    func testDidTapSaveMemberSet_ConsumesOffer() {
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: store
        )
        presenter.didChangeTotalAmount("35000")
        presenter.didPerformMainShare()
        XCTAssertTrue(presenter.showsMemberSetOffer)

        presenter.didTapSaveMemberSet(name: "いつもの飲み会")

        XCTAssertFalse(presenter.showsMemberSetOffer)
        XCTAssertTrue(store.memberSetOfferConsumed)
        XCTAssertEqual(store.memberSets.map(\.name), ["いつもの飲み会"])
    }

    func testShowsMemberSetOffer_AfterSettle_IsFalseUntilNextShare() {
        let presenter = makeValidPresenter().presenter
        presenter.didPerformMainShare()
        XCTAssertTrue(presenter.showsMemberSetOffer)

        presenter.didTapSettleComplete()

        XCTAssertFalse(presenter.showsMemberSetOffer)
        presenter.didChangeTotalAmount("35000")
        presenter.didPerformMainShare()
        XCTAssertTrue(presenter.showsMemberSetOffer)
    }

    func testShowsMemberSetOffer_WhenConsumedOnDisk_StaysFalseAfterSettleShare() {
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: store
        )
        presenter.didChangeTotalAmount("35000")
        presenter.didPerformMainShare()
        presenter.didDismissMemberSetOffer()
        presenter.didTapSettleComplete()
        presenter.didChangeTotalAmount("35000")
        presenter.didPerformMainShare()

        XCTAssertFalse(presenter.showsMemberSetOffer)
    }

    private func makeValidPresenter() -> (
        presenter: SakuttoSplitPresenter,
        store: InMemoryBillSessionStore
    ) {
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(
            interactor: CalculatingSpyInteractor(),
            sessionStore: store
        )
        presenter.didChangeTotalAmount("35000")
        return (presenter, store)
    }
}
