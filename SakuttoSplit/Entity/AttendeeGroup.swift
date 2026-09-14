//
//  AttendeeGroup.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// 割り勘の参加者グループ（ドメインモデル）
struct AttendeeGroup: Identifiable, Equatable {
    let id: UUID
    var name: String
    var count: Int
    var mode: PaymentMode
    var fixedAmount: Int
    var ratio: Decimal

    init(
        id: UUID = UUID(),
        name: String,
        count: Int,
        mode: PaymentMode,
        fixedAmount: Int = 0,
        ratio: Decimal = 1
    ) {
        self.id = id
        self.name = name
        self.count = count
        self.mode = mode
        self.fixedAmount = fixedAmount
        self.ratio = ratio
    }
}
