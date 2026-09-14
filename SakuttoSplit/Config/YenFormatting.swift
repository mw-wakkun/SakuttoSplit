//
//  YenFormatting.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import Foundation

/// 表示とシェア文専用の円金額フォーマット。入力・Snapshot の正本は数字文字列のまま
enum YenFormatting {
    private static let locale = Locale(identifier: "ja_JP")

    /// 符号なし・整数・グループ化。負値は呼び出し側で `abs` 済みを渡す
    static func grouped(_ value: Int) -> String {
        abs(value).formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(0))
                .grouping(.automatic)
        )
    }

    /// `viewState.totalAmountText` のような数字文字列をグループ化する。空は 0
    static func grouped(fromDigitText text: String) -> String {
        grouped(Int(text) ?? 0)
    }
}
