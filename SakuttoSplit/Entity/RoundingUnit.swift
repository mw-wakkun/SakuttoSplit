//
//  RoundingUnit.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// 割り勘金額の端数処理単位（切り捨て）
enum RoundingUnit: Int, CaseIterable, Equatable, Sendable {
    case one = 1
    case ten = 10
    case hundred = 100
    case fiveHundred = 500
    case thousand = 1000

    var displayName: String {
        "\(rawValue)円"
    }
}
