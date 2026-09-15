//
//  UnpaidReminderSchedule.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import Foundation

/// 未払いリマインダーの発火時刻。Foundation のみ。3 時間後、深夜は 10:00 へずらす
enum UnpaidReminderSchedule {
    static let delay: TimeInterval = 3 * 60 * 60

    static func fireDate(now: Date, calendar: Calendar = .current) -> Date {
        let candidate = now.addingTimeInterval(delay)
        let hour = calendar.component(.hour, from: candidate)
        guard (0...8).contains(hour) else {
            return candidate
        }
        var components = calendar.dateComponents([.year, .month, .day], from: candidate)
        components.hour = 10
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? candidate
    }
}
