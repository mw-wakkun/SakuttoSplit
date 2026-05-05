//
//  SakuttoSplitPresenter.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI
import Combine

/// Viewの状態管理と、Interactor/Routerとの橋渡しを行うプレゼンター
final class SakuttoSplitPresenter: ObservableObject {
    
    // MARK: - Input Properties (Published)
    
    @Published var totalAmountText: String = "" {
        didSet { calculate() }
    }
    @Published var selectedRoundingUnit: Int = 100 {
        didSet { calculate() }
    }
    @Published var groups: [AttendeeGroup] = [
        AttendeeGroup(name: "部長", countText: "1", isFixed: true, fixedAmountText: "10000"),
        AttendeeGroup(name: "一般", countText: "4", isFixed: false, ratioText: "1.0")
    ]
    
    // MARK: - Output Properties (Published)
    
    @Published private(set) var calculationResults: [SakuttoSplitInteractor.CalculationResult] = []
    @Published private(set) var collectedTotal: Int = 0
    @Published private(set) var difference: Int = 0
    
    // MARK: - Dependencies
    
    private let interactor: SakuttoSplitInteractor
    
    // MARK: - Lifecycle
    
    init(interactor: SakuttoSplitInteractor) {
        self.interactor = interactor
        calculate()
    }
    
    // MARK: - Internal Methods
    
    /// 現在の入力状況に基づいて再計算を行う
    func calculate() {
        let result = interactor.calculateBill(
            totalAmountText: totalAmountText,
            roundingUnit: selectedRoundingUnit,
            groups: groups
        )
        self.calculationResults = result.results
        self.collectedTotal = result.collectedTotal
        self.difference = result.difference
    }
    
    /// 新しい参加者グループを末尾に追加する
    func addGroup() {
        let newGroupName = "新規グループ\(groups.count + 1)"
        groups.append(AttendeeGroup(name: newGroupName, countText: "1", isFixed: false, ratioText: "1.0"))
        calculate()
    }
    
    /// 指定されたIDを持つグループを削除する
    func removeGroup(id: UUID) {
        groups.removeAll(where: { $0.id == id })
        calculate()
    }
}
