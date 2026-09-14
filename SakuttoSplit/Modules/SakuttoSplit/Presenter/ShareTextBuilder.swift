//
//  ShareTextBuilder.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// 計算結果のシェア文面を組み立てる。項目順は維持し、表示だけ Formatter を使う
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
        var text = "本日のお会計\n"
        text += totalLine(totalAmountText)
        text += "----------------\n"

        for result in results {
            text += personLine(label: result.name, amountPerPerson: result.amountPerPerson)
        }

        text += "----------------\n"
        let differenceLabel = difference >= 0 ? "余剰" : "不足"
        text += "\(differenceLabel)  \(YenFormatting.grouped(abs(difference)))円\n"
        text += transferRequestLine

        return text
    }

    /// 未払い席だけの再シェア文。全員済・席なしは空文字
    static func buildUnpaid(totalAmountText: String, unpaidSeats: [CollectionSeat]) -> String {
        guard !unpaidSeats.isEmpty else { return "" }

        var text = "未払いのお願い\n"
        text += totalLine(totalAmountText)
        text += "----------------\n"

        for seat in unpaidSeats {
            text += personLine(label: seat.label, amountPerPerson: seat.amountPerPerson)
        }

        text += "----------------\n"
        text += transferRequestLine

        return text
    }

    private static let transferRequestLine = "PayPay等で送金をお願いします"

    private static func totalLine(_ totalAmountText: String) -> String {
        "総額  \(YenFormatting.grouped(fromDigitText: totalAmountText))円\n"
    }

    private static func personLine(label: String, amountPerPerson: Int) -> String {
        "\(label)  1人 \(YenFormatting.grouped(amountPerPerson))円\n"
    }
}
