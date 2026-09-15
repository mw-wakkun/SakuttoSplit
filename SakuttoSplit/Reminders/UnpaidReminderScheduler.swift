//
//  UnpaidReminderScheduler.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import Foundation
import UserNotifications

/// UserNotifications の唯一の実装。計算も Store も知らない
final class UnpaidReminderScheduler: UnpaidReminderScheduling {
    static let requestIdentifier = "io.github.mw-wakkun.SakuttoSplit.unpaidReminder"

    private(set) var authorizationStatus: UnpaidReminderAuthorizationStatus = .notDetermined

    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            return granted && authorizationStatus == .authorized
        } catch {
            await refreshStatus()
            return false
        }
    }

    func sync(unpaidCount: Int) {
        Task {
            await applySync(unpaidCount: unpaidCount)
        }
    }

    private func applySync(unpaidCount: Int) async {
        await refreshStatus()
        let center = UNUserNotificationCenter.current()
        guard authorizationStatus == .authorized else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
            return
        }
        if unpaidCount == 0 {
            center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
            try? await center.setBadgeCount(0)
            return
        }
        let now = Date()
        let fireDate = UnpaidReminderSchedule.fireDate(now: now)
        guard fireDate > now else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
            try? await center.setBadgeCount(0)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notify.unpaid_push_title")
        content.body = String(localized: "notify.unpaid_push_body \(unpaidCount)")
        content.sound = .default
        content.badge = NSNumber(value: unpaidCount)
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.requestIdentifier,
            content: content,
            trigger: trigger
        )
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
        try? await center.add(request)
        try? await center.setBadgeCount(unpaidCount)
    }

    private func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = Self.status(from: settings.authorizationStatus)
    }

    private static func status(
        from authorizationStatus: UNAuthorizationStatus
    ) -> UnpaidReminderAuthorizationStatus {
        switch authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }
}
