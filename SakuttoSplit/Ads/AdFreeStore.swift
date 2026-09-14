//
//  AdFreeStore.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import Foundation

/// リワード完了で付与した広告オフ期限。UserDefaults のキーはここだけ
struct AdFreeStore {
    static let adFreeUntilKey = "ads.adFreeUntil"
    static let defaultDuration: TimeInterval = 24 * 60 * 60

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var adFreeUntil: Date? {
        defaults.object(forKey: Self.adFreeUntilKey) as? Date
    }

    func isAdFree(at now: Date) -> Bool {
        guard let until = adFreeUntil else { return false }
        return now < until
    }

    func remaining(at now: Date) -> TimeInterval {
        guard let until = adFreeUntil else { return 0 }
        return max(0, until.timeIntervalSince(now))
    }

    func grant(from now: Date, duration: TimeInterval) {
        defaults.set(now.addingTimeInterval(duration), forKey: Self.adFreeUntilKey)
    }
}

enum AdFreeRemaining {
    /// 表示用。1 時間未満でも 1 時間として出す
    static func hours(remaining: TimeInterval) -> Int {
        max(1, Int(ceil(remaining / 3600)))
    }
}
