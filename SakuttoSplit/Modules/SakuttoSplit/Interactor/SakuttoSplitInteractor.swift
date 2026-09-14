//
//  SakuttoSplitInteractor.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// 割り勘計算のユースケース実装
final class SakuttoSplitInteractor: SakuttoSplitInteractorProtocol {

    /// 与えられた条件に基づいて割り勘の計算を実行する
    func calculateBill(_ input: BillCalculationInput) -> BillCalculationOutput {
        let totalAmount = input.totalAmount
        let roundingUnit = input.roundingUnit.rawValue
        var results: [GroupCalculationResult] = []

        var fixedTotal = 0
        for group in input.groups where group.mode == .fixed {
            fixedTotal += group.fixedAmount * group.count
        }

        let remainingAmount = max(0, totalAmount - fixedTotal)

        var totalRatio = 0.0
        for group in input.groups where group.mode == .ratio {
            totalRatio += doubleRatio(of: group) * Double(group.count)
        }

        for group in input.groups {
            switch group.mode {
            case .fixed:
                results.append(
                    GroupCalculationResult(
                        groupID: group.id,
                        name: group.name,
                        amountPerPerson: group.fixedAmount,
                        total: group.fixedAmount * group.count
                    )
                )
            case .ratio:
                if totalRatio > 0 {
                    // 倍率配分と端数切り捨て。演算は従来どおり Double で行い期待値を維持する
                    let rawAmount = (Double(remainingAmount) / totalRatio) * doubleRatio(of: group)
                    let unit = Double(roundingUnit)
                    let roundedAmount = Int(rawAmount / unit) * roundingUnit

                    results.append(
                        GroupCalculationResult(
                            groupID: group.id,
                            name: group.name,
                            amountPerPerson: roundedAmount,
                            total: roundedAmount * group.count
                        )
                    )
                } else {
                    results.append(
                        GroupCalculationResult(
                            groupID: group.id,
                            name: group.name,
                            amountPerPerson: 0,
                            total: 0
                        )
                    )
                }
            }
        }

        let collectedTotal = results.reduce(0) { $0 + $1.total }
        let difference = collectedTotal - totalAmount

        return BillCalculationOutput(
            results: results,
            collectedTotal: collectedTotal,
            difference: difference
        )
    }

    private func doubleRatio(of group: AttendeeGroup) -> Double {
        NSDecimalNumber(decimal: group.ratio).doubleValue
    }
}
