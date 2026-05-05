//
//  AttendeeGroup.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// 割り勘の参加者グループを表すデータモデル
struct AttendeeGroup: Identifiable, Equatable {
    /// 一意の識別子
    let id = UUID()
    /// グループ名（例: 部長、一般など）
    var name: String
    
    // UIからの入力を保持するためのプロパティ
    var countText: String = "1"
    var isFixed: Bool = false
    var fixedAmountText: String = "0"
    var ratioText: String = "1.0"

    // MARK: - Computed Properties
    
    /// 入力文字列を整数に変換した人数。変換不可の場合は0を返す
    var count: Int { Int(countText) ?? 0 }
    
    /// 入力文字列を整数に変換した固定金額
    var fixedAmount: Int { Int(fixedAmountText) ?? 0 }
    
    /// 入力文字列を数値に変換した按分比率（倍率）
    var ratio: Double { Double(ratioText) ?? 0.0 }
}
