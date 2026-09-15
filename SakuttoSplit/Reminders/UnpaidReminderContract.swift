//
//  UnpaidReminderContract.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import Foundation

/// OS の通知許可。provisional / ephemeral は authorized として扱う
enum UnpaidReminderAuthorizationStatus: Equatable {
    case notDetermined
    case authorized
    case denied
}

/// 未払いローカル通知の予約。未払い人数は引数で受け取る。Store は読まない
protocol UnpaidReminderScheduling {
    var authorizationStatus: UnpaidReminderAuthorizationStatus { get }
    func requestAuthorizationIfNeeded() async -> Bool
    func sync(unpaidCount: Int)
}

/// テストと Presenter のデフォルト。本番 Router からは使わない
struct NullUnpaidReminderScheduler: UnpaidReminderScheduling {
    var authorizationStatus: UnpaidReminderAuthorizationStatus { .notDetermined }

    func requestAuthorizationIfNeeded() async -> Bool {
        false
    }

    func sync(unpaidCount: Int) {}
}
