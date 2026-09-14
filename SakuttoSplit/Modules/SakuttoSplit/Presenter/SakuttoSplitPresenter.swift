//
//  SakuttoSplitPresenter.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Combine
import Foundation

/// View の状態管理と、Interactor への計算依頼を行うプレゼンター
@MainActor
final class SakuttoSplitPresenter: SakuttoSplitPresenterProtocol {

    @Published private(set) var viewState: SakuttoSplitViewState

    private let interactor: SakuttoSplitInteractorProtocol

    convenience init(interactor: SakuttoSplitInteractorProtocol) {
        self.init(interactor: interactor, initialState: .initial)
    }

    init(
        interactor: SakuttoSplitInteractorProtocol,
        initialState: SakuttoSplitViewState
    ) {
        self.interactor = interactor
        var state = initialState
        Self.applyCalculation(to: &state, interactor: interactor)
        self.viewState = state
    }

    func didChangeTotalAmount(_ text: String) {
        applyUpdate { $0.totalAmountText = InputLimits.sanitizedTotalAmountText(text) }
    }

    func didChangeRoundingUnit(_ unit: RoundingUnit) {
        applyUpdate { $0.roundingUnit = unit }
    }

    func didChangeGroupName(id: UUID, name: String) {
        applyUpdate { state in
            guard let index = state.groups.firstIndex(where: { $0.id == id }) else { return }
            state.groups[index].name = name
        }
    }

    func didChangeGroupCount(id: UUID, countText: String) {
        applyUpdate { state in
            guard let index = state.groups.firstIndex(where: { $0.id == id }) else { return }
            state.groups[index].countText = InputLimits.sanitizedCountText(countText)
        }
    }

    func didChangePaymentMode(id: UUID, mode: PaymentMode) {
        applyUpdate { state in
            guard let index = state.groups.firstIndex(where: { $0.id == id }) else { return }
            state.groups[index].mode = mode
        }
    }

    func didChangeFixedAmount(id: UUID, text: String) {
        applyUpdate { state in
            guard let index = state.groups.firstIndex(where: { $0.id == id }) else { return }
            state.groups[index].fixedAmountText = InputLimits.sanitizedFixedAmountText(text)
        }
    }

    func didChangeRatio(id: UUID, text: String) {
        applyUpdate { state in
            guard let index = state.groups.firstIndex(where: { $0.id == id }) else { return }
            state.groups[index].ratioText = InputLimits.sanitizedRatioText(text)
        }
    }

    func didTapAddGroup() {
        applyUpdate { state in
            let newGroupName = "新規グループ\(state.groups.count + 1)"
            state.groups.append(
                AttendeeGroupDraft(name: newGroupName, countText: "1", mode: .ratio, ratioText: "1.0")
            )
        }
    }

    func didTapRemoveGroup(id: UUID) {
        applyUpdate { state in
            state.groups.removeAll { $0.id == id }
        }
    }

    /// 入力が変わったときだけ 1 回計算し、viewState を 1 回だけ書き換える
    private func applyUpdate(_ update: (inout SakuttoSplitViewState) -> Void) {
        var next = viewState
        update(&next)
        guard next != viewState else { return }
        Self.applyCalculation(to: &next, interactor: interactor)
        viewState = next
    }

    private static func applyCalculation(
        to state: inout SakuttoSplitViewState,
        interactor: SakuttoSplitInteractorProtocol
    ) {
        let input = makeInput(from: state)
        let output = interactor.calculateBill(input)
        state.results = output.results
        state.difference = output.difference
        state.validationIssue = validationIssue(
            groupsEmpty: state.groups.isEmpty,
            totalAmountText: state.totalAmountText,
            input: input
        )
        state.shareText = ShareTextBuilder.build(from: state)
    }

    private static func makeInput(from state: SakuttoSplitViewState) -> BillCalculationInput {
        BillCalculationInput(
            totalAmount: Int(state.totalAmountText) ?? 0,
            roundingUnit: state.roundingUnit,
            groups: state.groups.map { $0.toDomain() }
        )
    }

    private static func validationIssue(
        groupsEmpty: Bool,
        totalAmountText: String,
        input: BillCalculationInput
    ) -> SplitValidationIssue? {
        if groupsEmpty {
            return .noGroups
        }
        if totalAmountText.isEmpty {
            return .emptyTotalAmount
        }
        let fixedTotal = input.groups.reduce(into: 0) { sum, group in
            if group.mode == .fixed {
                sum += group.fixedAmount * group.count
            }
        }
        if fixedTotal > input.totalAmount {
            return .fixedAmountExceedsTotal
        }
        return nil
    }
}
