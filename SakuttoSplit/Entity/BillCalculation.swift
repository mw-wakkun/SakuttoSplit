//
//  BillCalculation.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// 割り勘計算の入力
struct BillCalculationInput: Equatable {
    /// お会計の総額（円）。呼び出し側で文字列から変換する
    let totalAmount: Int
    /// 端数処理の単位
    let roundingUnit: RoundingUnit
    /// 計算対象の参加者グループ（ドメイン値）
    let groups: [AttendeeGroup]
}

/// グループ単位の計算結果
struct GroupCalculationResult: Equatable, Identifiable {
    var id: UUID { groupID }

    /// 元グループの識別子。同名グループを区別する
    let groupID: UUID
    let name: String
    let amountPerPerson: Int
    let total: Int
}

/// 割り勘計算の出力
struct BillCalculationOutput: Equatable {
    let results: [GroupCalculationResult]
    let collectedTotal: Int
    let difference: Int
}
