//
//  SakuttoSplitFocus.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// 割り勘画面の入力フォーカス。toolbar の完了でまとめて閉じる
enum SakuttoSplitFocus: Hashable {
    case totalAmount
    case groupName(UUID)
    case groupCount(UUID)
    case fixedAmount(UUID)
    case ratio(UUID)

    /// キーボード「次へ」。最後の欄、または次グループが無ければ `nil`（フォーカス解除）
    func next(
        in groups: [AttendeeGroupDraft],
        isPaymentExpanded: (UUID) -> Bool = { _ in true }
    ) -> SakuttoSplitFocus? {
        switch self {
        case .totalAmount:
            return groups.first.map { .groupName($0.id) }
        case .groupName(let id):
            return .groupCount(id)
        case .groupCount(let id):
            guard let group = groups.first(where: { $0.id == id }) else {
                return Self.nextGroupName(after: id, groups: groups)
            }
            if isPaymentExpanded(id) {
                return group.mode == .fixed ? .fixedAmount(id) : .ratio(id)
            }
            return Self.nextGroupName(after: id, groups: groups)
        case .fixedAmount(let id), .ratio(let id):
            return Self.nextGroupName(after: id, groups: groups)
        }
    }

    private static func nextGroupName(after id: UUID, groups: [AttendeeGroupDraft]) -> SakuttoSplitFocus? {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return nil }
        let nextIndex = groups.index(after: index)
        guard nextIndex < groups.endIndex else { return nil }
        return .groupName(groups[nextIndex].id)
    }
}
