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
}
