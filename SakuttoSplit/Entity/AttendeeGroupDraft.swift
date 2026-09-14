//
//  AttendeeGroupDraft.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// TextField 用の入力途中データ。Interactor には渡さず、ドメインへ変換してから計算する
struct AttendeeGroupDraft: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var countText: String
    var mode: PaymentMode
    var fixedAmountText: String
    var ratioText: String

    init(
        id: UUID = UUID(),
        name: String,
        countText: String = "1",
        mode: PaymentMode = .ratio,
        fixedAmountText: String = "0",
        ratioText: String = "1.0"
    ) {
        self.id = id
        self.name = name
        self.countText = countText
        self.mode = mode
        self.fixedAmountText = fixedAmountText
        self.ratioText = ratioText
    }

    /// 現行仕様どおり、変換できない入力は 0 にする
    func toDomain() -> AttendeeGroup {
        AttendeeGroup(
            id: id,
            name: name,
            count: Int(countText) ?? 0,
            mode: mode,
            fixedAmount: Int(fixedAmountText) ?? 0,
            ratio: Self.parseRatio(ratioText)
        )
    }

    private static func parseRatio(_ text: String) -> Decimal {
        guard let value = Double(text), value.isFinite else { return 0 }
        return Decimal(value)
    }
}
