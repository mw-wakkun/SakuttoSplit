//
//  AdsContract.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import Combine
import Foundation
import UIKit

/// 広告の正本。load / 提示資格 / 広告オフ期限を持つ
@MainActor
protocol AdsControlling: ObservableObject {
    var isAdFree: Bool { get }
    /// UI 用。未 load でもボタンは出してよい
    var canRequestRewarded: Bool { get }
    var rewardUnavailable: Bool { get }
    func startLoadingIfNeeded() async
    func refreshAdFreeState()
    func didTapHideAdsForToday(from rootViewController: UIViewController)
    func presentRewarded(
        from rootViewController: UIViewController,
        purpose: RewardedPurpose,
        onEarned: (() -> Void)?
    )
    func presentInterstitialIfEligible(from rootViewController: UIViewController)
}

/// リワード視聴の目的。完了時に該当報酬だけ付与する
enum RewardedPurpose: Equatable {
    case adFree24h
    case extraMemberSetSlot
}

/// SDK をテストから切り離すためのインタースティシャル読み込み
@MainActor
protocol InterstitialAdHandling: AnyObject {
    func load(adUnitID: String) async -> (any InterstitialPresenting)?
}

/// 読み込み済み全画面。GoogleMobileAds の型は出さない
@MainActor
protocol InterstitialPresenting: AnyObject {
    var onDidFinish: (() -> Void)? { get set }
    func present(from rootViewController: UIViewController)
}

/// SDK をテストから切り離すためのリワード読み込み
@MainActor
protocol RewardedAdHandling: AnyObject {
    func load(adUnitID: String) async -> (any RewardedPresenting)?
}

/// 読み込み済みリワード。完了コールバックでのみ報酬を付ける
@MainActor
protocol RewardedPresenting: AnyObject {
    var onDidEarnReward: (() -> Void)? { get set }
    var onDidFinish: (() -> Void)? { get set }
    func present(from rootViewController: UIViewController)
}
