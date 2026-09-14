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
        let differenceLabel = difference >= 0 ? "余剰" : "不足"
        let personLines = results.map {
            personLine(label: $0.name, amountPerPerson: $0.amountPerPerson)
        }
        return [
            "本日のお会計\n",
            totalLine(totalAmountText),
            "----------------\n",
            personLines.joined(),
            "----------------\n",
            "\(differenceLabel)  \(YenFormatting.grouped(abs(difference)))円\n",
            transferRequestLine
        ].joined()
    }

    /// 未払い席だけの再シェア文。全員済・席なしは空文字
    static func buildUnpaid(totalAmountText: String, unpaidSeats: [CollectionSeat]) -> String {
        guard !unpaidSeats.isEmpty else { return "" }

        let personLines = unpaidSeats.map {
            personLine(label: $0.label, amountPerPerson: $0.amountPerPerson)
        }
        return [
            "未払いのお願い\n",
            totalLine(totalAmountText),
            "----------------\n",
            personLines.joined(),
            "----------------\n",
            transferRequestLine
        ].joined()
    }

    private static let transferRequestLine = "PayPay等で送金をお願いします"

    private static func totalLine(_ totalAmountText: String) -> String {
        "総額  \(YenFormatting.grouped(fromDigitText: totalAmountText))円\n"
    }

    private static func personLine(label: String, amountPerPerson: Int) -> String {
        "\(label)  1人 \(YenFormatting.grouped(amountPerPerson))円\n"
    }
}
