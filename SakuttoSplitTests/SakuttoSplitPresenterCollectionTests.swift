//
//  SakuttoSplitPresenterCollectionTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import XCTest
@testable import SakuttoSplit

@MainActor
final class SakuttoSplitPresenterCollectionTests: XCTestCase {

    func testInit_CollectionIsEmpty_WhenTotalIsEmpty() {
        let presenter = SakuttoSplitPresenter(interactor: CalculatingSpyInteractor())

        XCTAssertTrue(presenter.collectionState.seats.isEmpty)
        XCTAssertEqual(presenter.unpaidShareText, "")
        XCTAssertEqual(presenter.viewState.validationIssue, .emptyTotalAmount)
    }

    func testDidChangeTotalAmount_WhenValid_CreatesSeatsForEachPerson() {
        let presenter = makeValidDefaultPresenter().presenter

        XCTAssertNil(presenter.viewState.validationIssue)
        XCTAssertEqual(presenter.collectionState.seats.map(\.label), [
            "部長 1", "一般 1", "一般 2", "一般 3", "一般 4"
        ])
        XCTAssertEqual(presenter.collectionState.seats.map(\.amountPerPerson), [
            10000, 6200, 6200, 6200, 6200
        ])
        XCTAssertTrue(presenter.collectionState.seats.allSatisfy { !$0.isPaid })
    }

    func testDidChangeTotalAmount_WhenInvalid_CollectionStaysEmpty() {
        let presenter = SakuttoSplitPresenter(interactor: CalculatingSpyInteractor())

        presenter.didChangeTotalAmount("5000")

        XCTAssertEqual(presenter.viewState.validationIssue, .fixedAmountExceedsTotal)
        XCTAssertTrue(presenter.collectionState.seats.isEmpty)
    }

    func testDidTapToggleCollectionSeat_DoesNotRecalculate_AndKeepsMainShareText() {
        let setup = makeValidDefaultPresenter()
        let presenter = setup.presenter
        let spy = setup.spy
        let callsBeforeToggle = spy.calculateCallCount
        let shareBefore = presenter.viewState.shareText
        let staffID = presenter.viewState.groups[1].id
        let seatID = CollectionSeatID(groupID: staffID, index: 1)

        presenter.didTapToggleCollectionSeat(id: seatID)

        XCTAssertEqual(spy.calculateCallCount, callsBeforeToggle)
        XCTAssertEqual(presenter.viewState.shareText, shareBefore)
        XCTAssertEqual(
            presenter.viewState.shareText,
            Self.expectedShareTextForDefaultGroupsTotal35000
        )
        XCTAssertEqual(presenter.collectionState.seats.map(\.isPaid), [
            false, false, true, false, false
        ])
    }

    func testDidTapMarkGroupCollectionPaid_MarksOnlyThatGroup_DoesNotRecalculate() {
        let setup = makeValidDefaultPresenter()
        let presenter = setup.presenter
        let spy = setup.spy
        let staffID = presenter.viewState.groups[1].id
        let managerID = presenter.viewState.groups[0].id
        presenter.didTapToggleCollectionSeat(id: CollectionSeatID(groupID: staffID, index: 0))
        let callsBefore = spy.calculateCallCount
        let shareBefore = presenter.viewState.shareText

        presenter.didTapMarkGroupCollectionPaid(groupID: staffID)

        XCTAssertEqual(spy.calculateCallCount, callsBefore)
        XCTAssertEqual(presenter.viewState.shareText, shareBefore)
        XCTAssertEqual(
            presenter.collectionState.seats.filter { $0.id.groupID == staffID }.map(\.isPaid),
            [true, true, true, true]
        )
        XCTAssertEqual(
            presenter.collectionState.seats.filter { $0.id.groupID == managerID }.map(\.isPaid),
            [false]
        )
    }

    func testDidTapMarkGroupCollectionPaid_WhenAlreadyAllPaid_IsNoOp() {
        let setup = makeValidDefaultPresenter()
        let presenter = setup.presenter
        let spy = setup.spy
        let staffID = presenter.viewState.groups[1].id
        presenter.didTapMarkGroupCollectionPaid(groupID: staffID)
        let before = presenter.collectionState
        let callsBefore = spy.calculateCallCount

        presenter.didTapMarkGroupCollectionPaid(groupID: staffID)

        XCTAssertEqual(presenter.collectionState, before)
        XCTAssertEqual(spy.calculateCallCount, callsBefore)
    }

    func testDidTapMarkGroupCollectionPaid_UnknownGroup_DoesNotChangeState() {
        let setup = makeValidDefaultPresenter()
        let presenter = setup.presenter
        let spy = setup.spy
        let before = presenter.collectionState
        let callsBefore = spy.calculateCallCount

        presenter.didTapMarkGroupCollectionPaid(groupID: UUID())

        XCTAssertEqual(presenter.collectionState, before)
        XCTAssertEqual(spy.calculateCallCount, callsBefore)
    }

    func testDidTapToggleCollectionSeat_UnknownID_DoesNotChangeState() {
        let setup = makeValidDefaultPresenter()
        let presenter = setup.presenter
        let spy = setup.spy
        let before = presenter.collectionState
        let callsBefore = spy.calculateCallCount

        presenter.didTapToggleCollectionSeat(
            id: CollectionSeatID(groupID: UUID(), index: 0)
        )

        XCTAssertEqual(presenter.collectionState, before)
        XCTAssertEqual(spy.calculateCallCount, callsBefore)
    }

    func testDidChangeGroupCount_4To5_AppendsUnpaidSeat_KeepsPaid() {
        let presenter = makeValidDefaultPresenter().presenter
        let staffID = presenter.viewState.groups[1].id
        presenter.didTapToggleCollectionSeat(id: CollectionSeatID(groupID: staffID, index: 0))
        presenter.didTapToggleCollectionSeat(id: CollectionSeatID(groupID: staffID, index: 2))

        presenter.didChangeGroupCount(id: staffID, countText: "5")

        let staffSeats = presenter.collectionState.seats.filter { $0.id.groupID == staffID }
        XCTAssertEqual(staffSeats.map(\.label), ["一般 1", "一般 2", "一般 3", "一般 4", "一般 5"])
        XCTAssertEqual(staffSeats.map(\.isPaid), [true, false, true, false, false])
    }

    func testDidChangeGroupCount_4To3_DropsTrailingSeat_KeepsRemainingPaid() {
        let presenter = makeValidDefaultPresenter().presenter
        let staffID = presenter.viewState.groups[1].id
        presenter.didTapToggleCollectionSeat(id: CollectionSeatID(groupID: staffID, index: 0))
        presenter.didTapToggleCollectionSeat(id: CollectionSeatID(groupID: staffID, index: 2))

        presenter.didChangeGroupCount(id: staffID, countText: "3")

        let staffSeats = presenter.collectionState.seats.filter { $0.id.groupID == staffID }
        XCTAssertEqual(staffSeats.map(\.label), ["一般 1", "一般 2", "一般 3"])
        XCTAssertEqual(staffSeats.map(\.isPaid), [true, false, true])
    }

    func testDidChangeGroupName_UpdatesLabels_KeepsPaid() {
        let presenter = makeValidDefaultPresenter().presenter
        let staffID = presenter.viewState.groups[1].id
        presenter.didTapToggleCollectionSeat(id: CollectionSeatID(groupID: staffID, index: 1))

        presenter.didChangeGroupName(id: staffID, name: "スタッフ")

        let staffSeats = presenter.collectionState.seats.filter { $0.id.groupID == staffID }
        XCTAssertEqual(staffSeats.map(\.label), ["スタッフ 1", "スタッフ 2", "スタッフ 3", "スタッフ 4"])
        XCTAssertEqual(staffSeats.map(\.isPaid), [false, true, false, false])
    }

    func testDidChangeTotalAmount_KeepsSeatIDs_UpdatesAmounts() {
        let presenter = makeValidDefaultPresenter().presenter
        let idsBefore = presenter.collectionState.seats.map(\.id)
        let staffID = presenter.viewState.groups[1].id
        presenter.didTapToggleCollectionSeat(id: CollectionSeatID(groupID: staffID, index: 0))

        presenter.didChangeTotalAmount("40000")

        XCTAssertEqual(presenter.collectionState.seats.map(\.id), idsBefore)
        XCTAssertEqual(presenter.collectionState.seats.map(\.amountPerPerson), [
            10000, 7500, 7500, 7500, 7500
        ])
        XCTAssertEqual(presenter.collectionState.seats.map(\.isPaid), [
            false, true, false, false, false
        ])
    }

    func testDidTapSettleComplete_PersistsPaidSeatKeys_AndClearsCollection() {
        let setup = makeValidDefaultPresenter()
        let presenter = setup.presenter
        let store = setup.store
        let staffID = presenter.viewState.groups[1].id
        let paidID = CollectionSeatID(groupID: staffID, index: 1)
        presenter.didTapToggleCollectionSeat(id: paidID)
        let paidKeys = presenter.collectionState.paidSeatKeys
        XCTAssertEqual(paidKeys, [paidID.rawValue])

        presenter.didTapSettleComplete()

        XCTAssertEqual(store.lastBill?.paidSeatKeys, paidKeys)
        XCTAssertTrue(presenter.collectionState.seats.isEmpty)
        XCTAssertEqual(presenter.unpaidShareText, "")
        XCTAssertEqual(presenter.viewState.validationIssue, .emptyTotalAmount)
    }

    func testDidEnterBackground_PersistsPaidSeatKeys_WithoutRecalculating() {
        let setup = makeValidDefaultPresenter()
        let presenter = setup.presenter
        let spy = setup.spy
        let store = setup.store
        let staffID = presenter.viewState.groups[1].id
        let paidID = CollectionSeatID(groupID: staffID, index: 0)
        presenter.didTapToggleCollectionSeat(id: paidID)
        let callsBefore = spy.calculateCallCount

        presenter.didEnterBackground()

        XCTAssertEqual(spy.calculateCallCount, callsBefore)
        XCTAssertEqual(store.lastBill?.paidSeatKeys, [paidID.rawValue])
        XCTAssertEqual(presenter.collectionState.paidSeatKeys, [paidID.rawValue])
    }

    func testDidTapRestoreLastBill_RestoresPaidSeats_DropsUnknownKeys() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let groupID = UUID()
        let realKey = CollectionSeatID(groupID: groupID, index: 0).rawValue
        let ghostKey = CollectionSeatID(groupID: UUID(), index: 99).rawValue
        store.saveLastBill(
            BillSnapshot(
                totalAmountText: "35000",
                roundingUnit: .hundred,
                groups: [
                    AttendeeGroupDraft(
                        id: groupID,
                        name: "全員",
                        countText: "2",
                        mode: .ratio,
                        ratioText: "1.0"
                    )
                ],
                paidSeatKeys: [realKey, ghostKey]
            )
        )
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)

        presenter.didTapRestoreLastBill()

        XCTAssertEqual(presenter.collectionState.seats.map(\.label), ["全員 1", "全員 2"])
        XCTAssertEqual(presenter.collectionState.seats.map(\.isPaid), [true, false])
        XCTAssertEqual(presenter.collectionState.paidSeatKeys, [realKey])
        XCTAssertFalse(presenter.collectionState.paidSeatKeys.contains(ghostKey))
    }

    func testDidTapRestoreLastBill_Schema1Snapshot_AllUnpaid() {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let groupID = UUID()
        store.saveLastBill(
            BillSnapshot(
                totalAmountText: "35000",
                roundingUnit: .hundred,
                groups: [
                    AttendeeGroupDraft(
                        id: groupID,
                        name: "全員",
                        countText: "2",
                        mode: .ratio,
                        ratioText: "1.0"
                    )
                ],
                paidSeatKeys: [],
                schemaVersion: 1
            )
        )
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)

        presenter.didTapRestoreLastBill()

        XCTAssertTrue(presenter.collectionState.seats.allSatisfy { !$0.isPaid })
        XCTAssertEqual(presenter.collectionState.seats.count, 2)
    }

    func testDidTapSettleComplete_ThenRestore_RestoresPaidSeats() {
        let setup = makeValidDefaultPresenter()
        let presenter = setup.presenter
        let staffID = presenter.viewState.groups[1].id
        let paidID = CollectionSeatID(groupID: staffID, index: 3)
        presenter.didTapToggleCollectionSeat(id: paidID)

        presenter.didTapSettleComplete()
        XCTAssertTrue(presenter.collectionState.seats.isEmpty)

        presenter.didTapRestoreLastBill()

        XCTAssertEqual(presenter.collectionState.seats.map(\.isPaid), [
            false, false, false, false, true
        ])
        XCTAssertEqual(presenter.collectionState.paidSeatKeys, [paidID.rawValue])
    }

    /// 同 ID の 2 グループを restore すると後続だけ新しい UUID になる。先頭の済は残る
    func testDidTapRestoreLastBill_DuplicateGroupIDs_BecomeUnique_KeepsFirstPaid() {
        let sharedID = UUID()
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let paidKey = CollectionSeatID(groupID: sharedID, index: 0).rawValue
        store.saveLastBill(
            BillSnapshot(
                totalAmountText: "20000",
                roundingUnit: .hundred,
                groups: [
                    AttendeeGroupDraft(
                        id: sharedID,
                        name: "A",
                        countText: "1",
                        mode: .ratio,
                        ratioText: "1.0"
                    ),
                    AttendeeGroupDraft(
                        id: sharedID,
                        name: "B",
                        countText: "1",
                        mode: .ratio,
                        ratioText: "1.0"
                    )
                ],
                paidSeatKeys: [paidKey]
            )
        )
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)

        presenter.didTapRestoreLastBill()

        let ids = presenter.viewState.groups.map(\.id)
        XCTAssertEqual(ids.count, 2)
        XCTAssertEqual(Set(ids).count, 2)
        XCTAssertEqual(ids[0], sharedID)
        XCTAssertNotEqual(ids[1], sharedID)
        XCTAssertEqual(presenter.viewState.groups.map(\.name), ["A", "B"])
        XCTAssertEqual(presenter.collectionState.seats.map(\.isPaid), [true, false])
        XCTAssertEqual(presenter.collectionState.paidSeatKeys, [paidKey])
    }

    /// 編成適用でも同 ID は分かれる。席は未払いのまま
    func testDidTapApplyMemberSet_DuplicateGroupIDs_BecomeUnique() {
        let sharedID = UUID()
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("20000")
        let memberSet = MemberSet(
            name: "重複",
            roundingUnit: .hundred,
            groups: [
                AttendeeGroupDraft(
                    id: sharedID,
                    name: "A",
                    countText: "1",
                    mode: .ratio,
                    ratioText: "1.0"
                ),
                AttendeeGroupDraft(
                    id: sharedID,
                    name: "B",
                    countText: "1",
                    mode: .ratio,
                    ratioText: "1.0"
                )
            ]
        )
        XCTAssertTrue(store.saveMemberSet(memberSet))

        presenter.didTapApplyMemberSet(id: memberSet.id)

        let ids = presenter.viewState.groups.map(\.id)
        XCTAssertEqual(ids.count, 2)
        XCTAssertEqual(Set(ids).count, 2)
        XCTAssertEqual(ids[0], sharedID)
        XCTAssertNotEqual(ids[1], sharedID)
        XCTAssertEqual(presenter.viewState.groups.map(\.name), ["A", "B"])
        XCTAssertTrue(presenter.collectionState.seats.allSatisfy { !$0.isPaid })
    }

    func testDidTapApplyMemberSet_ClearsPaidEvenWhenGroupIDsMatch() {
        let setup = makeValidDefaultPresenter()
        let presenter = setup.presenter
        let store = setup.store
        let staffID = presenter.viewState.groups[1].id
        presenter.didTapToggleCollectionSeat(id: CollectionSeatID(groupID: staffID, index: 0))
        presenter.didTapSaveMemberSet(name: "いつもの")
        XCTAssertFalse(presenter.collectionState.paidSeatKeys.isEmpty)

        presenter.didTapApplyMemberSet(id: store.memberSets[0].id)

        XCTAssertTrue(presenter.collectionState.seats.allSatisfy { !$0.isPaid })
        XCTAssertTrue(presenter.collectionState.paidSeatKeys.isEmpty)
        XCTAssertEqual(presenter.collectionState.seats.count, 5)
    }

    func testDidChangeGroupCount_To21_CollapsesStaffGroupToOneRow() {
        let presenter = makeValidDefaultPresenter().presenter
        let staffID = presenter.viewState.groups[1].id
        presenter.didTapToggleCollectionSeat(id: CollectionSeatID(groupID: staffID, index: 0))

        presenter.didChangeGroupCount(id: staffID, countText: "21")

        let staffSeats = presenter.collectionState.seats.filter { $0.id.groupID == staffID }
        XCTAssertEqual(staffSeats.count, 1)
        XCTAssertEqual(staffSeats[0].label, "一般")
        XCTAssertNil(staffSeats[0].displayNumber)
        XCTAssertEqual(
            presenter.viewState.shareText.components(separatedBy: "\n")[0],
            "本日のお会計"
        )
    }

    func testUnpaidShareText_OmitsPaidSeats_DoesNotChangeMainShareText() {
        let presenter = makeValidDefaultPresenter().presenter
        let staffID = presenter.viewState.groups[1].id
        presenter.didTapToggleCollectionSeat(id: CollectionSeatID(groupID: staffID, index: 0))
        presenter.didTapToggleCollectionSeat(id: CollectionSeatID(groupID: staffID, index: 2))
        let mainShare = presenter.viewState.shareText

        XCTAssertEqual(
            presenter.viewState.shareText,
            Self.expectedShareTextForDefaultGroupsTotal35000
        )
        XCTAssertEqual(presenter.viewState.shareText, mainShare)
        XCTAssertEqual(
            presenter.unpaidShareText,
            """
            未払いのお願い
            総額  35,000円
            ----------------
            部長 1  1人 10,000円
            一般 2  1人 6,200円
            一般 4  1人 6,200円
            ----------------
            PayPay等で送金をお願いします
            """
        )
        XCTAssertTrue(presenter.isUnpaidShareEnabled)
    }

    func testIsUnpaidShareEnabled_WhenAllPaid_IsFalse() {
        let presenter = makeValidDefaultPresenter().presenter
        XCTAssertTrue(presenter.isUnpaidShareEnabled)

        for seat in presenter.collectionState.seats {
            presenter.didTapToggleCollectionSeat(id: seat.id)
        }

        XCTAssertTrue(presenter.collectionState.unpaidSeats.isEmpty)
        XCTAssertEqual(presenter.unpaidShareText, "")
        XCTAssertFalse(presenter.isUnpaidShareEnabled)
        XCTAssertEqual(
            presenter.viewState.shareText,
            Self.expectedShareTextForDefaultGroupsTotal35000
        )
    }

    func testIsUnpaidShareEnabled_WhenInvalid_IsFalse() {
        let presenter = SakuttoSplitPresenter(interactor: CalculatingSpyInteractor())

        XCTAssertTrue(presenter.collectionState.seats.isEmpty)
        XCTAssertFalse(presenter.isUnpaidShareEnabled)
        XCTAssertEqual(presenter.unpaidShareText, "")
    }

    private func makeValidDefaultPresenter() -> (
        presenter: SakuttoSplitPresenter,
        spy: CalculatingSpyInteractor,
        store: InMemoryBillSessionStore
    ) {
        let spy = CalculatingSpyInteractor()
        let store = InMemoryBillSessionStore()
        let presenter = SakuttoSplitPresenter(interactor: spy, sessionStore: store)
        presenter.didChangeTotalAmount("35000")
        return (presenter, spy, store)
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
