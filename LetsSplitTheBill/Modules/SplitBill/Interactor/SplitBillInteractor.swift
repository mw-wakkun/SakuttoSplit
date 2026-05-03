//
//  SplitBillInteractor.swift
//  LetsSplitTheBill
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// 割り勘の計算ロジック（ビジネスロジック）を専門に扱うインターラクター
final class SplitBillInteractor {
    
    /// 計算結果を保持するための構造体
    struct CalculationResult {
        let name: String
        let amountPerPerson: Int
        let total: Int
    }
    
    /// 与えられた条件に基づいて割り勘の計算を実行する
    /// - Parameters:
    ///   - totalAmountText: お会計の総額（文字列）
    ///   - roundingUnit: 端数処理の単位（円）
    ///   - groups: 計算対象の参加者グループ一覧
    /// - Returns: 計算結果、集金合計、過不足金のタプル
    func calculateBill(
        totalAmountText: String,
        roundingUnit: Int,
        groups: [AttendeeGroup]
    ) -> (results: [CalculationResult], collectedTotal: Int, difference: Int) {
        
        let totalAmount = Int(totalAmountText) ?? 0
        var results: [CalculationResult] = []
        
        // 1. 固定額グループの処理
        var fixedTotal = 0
        for group in groups where group.isFixed {
            fixedTotal += group.fixedAmount * group.count
        }
        
        // 残金（按分グループで分ける額）を算出。0円未満にならないよう保護
        let remainingAmount = max(0, totalAmount - fixedTotal)
        
        // 2. 按分（倍率）グループの重み合計を算出
        var totalRatio = 0.0
        for group in groups where !group.isFixed {
            totalRatio += group.ratio * Double(group.count)
        }
        
        // 3. 各グループの支払い金額を確定
        for group in groups {
            if group.isFixed {
                results.append(CalculationResult(
                    name: group.name,
                    amountPerPerson: group.fixedAmount,
                    total: group.fixedAmount * group.count
                ))
            } else {
                if totalRatio > 0 {
                    // 倍率に応じた配分計算と端数処理（切り捨て）
                    let rawAmount = (Double(remainingAmount) / totalRatio) * group.ratio
                    let unit = Double(roundingUnit)
                    let roundedAmount = Int(rawAmount / unit) * roundingUnit
                    
                    results.append(CalculationResult(
                        name: group.name,
                        amountPerPerson: roundedAmount,
                        total: roundedAmount * group.count
                    ))
                } else {
                    results.append(CalculationResult(name: group.name, amountPerPerson: 0, total: 0))
                }
            }
        }
        
        // 4. 全体の集計
        let collectedTotal = results.reduce(0) { $0 + $1.total }
        let difference = collectedTotal - totalAmount
        
        return (results, collectedTotal, difference)
    }
}
