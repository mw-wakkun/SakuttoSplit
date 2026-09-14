//
//  AdsContract.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import Combine
import Foundation
import UIKit

/// 精算完了後の全画面提示。計算 Presenter は GoogleMobileAds を知らない
@MainActor
protocol AdsRouting: AnyObject {
    func presentInterstitialIfEligible()
}

/// 広告の正本。load / 提示資格 / 広告オフ期限を持つ
@MainActor
protocol AdsControlling: ObservableObject {
    var isAdFree: Bool { get }
    /// UI 用。未 load でもボタンは出してよい
    var canRequestRewarded: Bool { get }
    func startLoadingIfNeeded()
    func didTapHideAdsForToday(from rootViewController: UIViewController)
    func presentInterstitialIfEligible(from rootViewController: UIViewController)
}
