//
//  AdEligibility.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import Foundation

/// SDK なしでバナー / インタースティシャルの資格を判定する純ロジック
struct AdEligibility: Equatable {
    /// リワード完了による広告オフ期間中
    var isAdFree: Bool
    /// このプロセスでインタースティシャルを既に出したか
    var hasPresentedInterstitialThisSession: Bool
    /// AdsController 生成（≒ SDK 利用開始）からの経過秒
    var elapsedSinceStart: TimeInterval
    /// インタースティシャルが load 済みか
    var isInterstitialLoaded: Bool

    static let interstitialMinimumElapsedSeconds: TimeInterval = 15

    var canShowBanner: Bool {
        !isAdFree
    }

    var canPresentInterstitial: Bool {
        !isAdFree
            && !hasPresentedInterstitialThisSession
            && elapsedSinceStart >= Self.interstitialMinimumElapsedSeconds
            && isInterstitialLoaded
    }
}
