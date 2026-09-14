//
//  PaymentMode.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// 参加者グループの支払い方法
enum PaymentMode: String, Equatable, Hashable, Sendable, Codable {
    /// 残金を倍率で按分する
    case ratio
    /// 1人あたりの固定額を支払う
    case fixed
}
