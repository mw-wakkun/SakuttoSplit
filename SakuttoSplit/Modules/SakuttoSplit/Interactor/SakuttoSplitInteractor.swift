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

        var fixedTotal = 0
        var totalRatio = 0.0
        for group in input.groups {
            switch group.mode {
            case .fixed:
                fixedTotal += group.fixedAmount * group.count
            case .ratio:
                totalRatio += doubleRatio(of: group) * Double(group.count)
            }
        }

        let remainingAmount = max(0, totalAmount - fixedTotal)
        let results = input.groups.map { group in
            result(
                for: group,
                remainingAmount: remainingAmount,
                totalRatio: totalRatio,
                roundingUnit: roundingUnit
            )
        }

        let collectedTotal = results.reduce(0) { $0 + $1.total }
        let difference = collectedTotal - totalAmount

        return BillCalculationOutput(
            results: results,
            collectedTotal: collectedTotal,
            difference: difference
        )
    }

    private func result(
        for group: AttendeeGroup,
        remainingAmount: Int,
        totalRatio: Double,
        roundingUnit: Int
    ) -> GroupCalculationResult {
        switch group.mode {
        case .fixed:
            return GroupCalculationResult(
                groupID: group.id,
                name: group.name,
                amountPerPerson: group.fixedAmount,
                total: group.fixedAmount * group.count
            )
        case .ratio:
            let amounts: (perPerson: Int, total: Int)?
            if totalRatio > 0 {
                // 倍率配分と端数切り捨て。演算は従来どおり Double で行い期待値を維持する
                let rawAmount = (Double(remainingAmount) / totalRatio) * doubleRatio(of: group)
                amounts = ratioAmounts(
                    rawAmount: rawAmount,
                    roundingUnit: roundingUnit,
                    count: group.count
                )
            } else {
                amounts = nil
            }
            return GroupCalculationResult(
                groupID: group.id,
                name: group.name,
                amountPerPerson: amounts?.perPerson ?? 0,
                total: amounts?.total ?? 0
            )
        }
    }

    private func doubleRatio(of group: AttendeeGroup) -> Double {
        NSDecimalNumber(decimal: group.ratio).doubleValue
    }

    /// 有限で Int に収まるときだけ現行式。非有限・範囲外・人数倍の溢れは 0
    private func ratioAmounts(
        rawAmount: Double,
        roundingUnit: Int,
        count: Int
    ) -> (perPerson: Int, total: Int)? {
        let unit = Double(roundingUnit)
        guard rawAmount.isFinite, unit.isFinite, unit > 0 else { return nil }
        let scaled = rawAmount / unit
        guard let truncated = intByTruncatingTowardZero(scaled) else { return nil }
        let (roundedAmount, roundedOverflow) = truncated.multipliedReportingOverflow(by: roundingUnit)
        guard !roundedOverflow else { return nil }
        let (total, totalOverflow) = roundedAmount.multipliedReportingOverflow(by: count)
        guard !totalOverflow else { return nil }
        return (roundedAmount, total)
    }

    /// Double(Int.max) は 2^63 になり Int() が trap するため、上限は排他にする
    private func intByTruncatingTowardZero(_ value: Double) -> Int? {
        guard value.isFinite,
              value >= Double(Int.min),
              value < Double(Int.max) else {
            return nil
        }
        return Int(value)
    }
}
