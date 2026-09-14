//
//  ShareTextBuilder.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// 計算結果のシェア文面を組み立てる
enum ShareTextBuilder {
    static func build(from state: SakuttoSplitViewState) -> String {
        build(
            totalAmountText: state.totalAmountText,
            results: state.results,
            difference: state.difference
        )
    }

    static func build(
        totalAmountText: String,
        results: [GroupCalculationResult],
        difference: Int
    ) -> String {
        var text = "🍻 本日のお会計 🍻\n"
        text += "総額: \(totalAmountText) 円\n"
        text += "----------------\n"

        for result in results {
            text += "\(result.name): 1人 \(result.amountPerPerson)円\n"
        }

        text += "----------------\n"
        if difference >= 0 {
            text += "✨ 余剰金: \(abs(difference))円\n"
        } else {
            text += "⚠️ 不足金: \(abs(difference))円\n"
        }
        text += "※PayPay等で送金をお願いします！"

        return text
    }

    /// 未払い席だけの再シェア文。全員済・席なしは空文字
    static func buildUnpaid(totalAmountText: String, unpaidSeats: [CollectionSeat]) -> String {
        guard !unpaidSeats.isEmpty else { return "" }

        var text = "🍻 未払いのお願い 🍻\n"
        text += "総額: \(totalAmountText) 円\n"
        text += "----------------\n"

        for seat in unpaidSeats {
            text += "\(seat.label): 1人 \(seat.amountPerPerson)円\n"
        }

        text += "----------------\n"
        text += "※PayPay等で送金をお願いします！"

        return text
    }
}
