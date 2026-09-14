//
//  AdsController.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import Combine
import Foundation
import GoogleMobileAds
import UIKit

/// 広告の正本。計算 Presenter はここを知らず、View が精算完了の直後に提示を依頼する
@MainActor
final class AdsController: ObservableObject, AdsControlling {

    @Published private(set) var isAdFree: Bool
    @Published private(set) var canRequestRewarded = false

    private let interstitialAdUnitID: String
    private let loader: any InterstitialAdHandling
    private let now: () -> Date
    private let startDate: Date

    private var readyInterstitial: (any InterstitialPresenting)?
    private var presentingInterstitial: (any InterstitialPresenting)?
    private var hasPresentedInterstitialThisSession = false
    private var isLoadingInterstitial = false

    convenience init(
        interstitialAdUnitID: String,
        rewardedAdUnitID: String = "",
        now: @escaping () -> Date = Date.init,
        startDate: Date? = nil,
        isAdFree: Bool = false
    ) {
        self.init(
            interstitialAdUnitID: interstitialAdUnitID,
            rewardedAdUnitID: rewardedAdUnitID,
            loader: GoogleInterstitialLoader(),
            now: now,
            startDate: startDate,
            isAdFree: isAdFree
        )
    }

    init(
        interstitialAdUnitID: String,
        rewardedAdUnitID _: String = "",
        loader: any InterstitialAdHandling,
        now: @escaping () -> Date = Date.init,
        startDate: Date? = nil,
        isAdFree: Bool = false
    ) {
        self.interstitialAdUnitID = interstitialAdUnitID
        self.loader = loader
        self.now = now
        self.startDate = startDate ?? now()
        self.isAdFree = isAdFree
    }

    func startLoadingIfNeeded() async {
        guard !interstitialAdUnitID.isEmpty else { return }
        guard readyInterstitial == nil, presentingInterstitial == nil else { return }
        guard !isLoadingInterstitial else { return }

        isLoadingInterstitial = true
        let loaded = await loader.load(adUnitID: interstitialAdUnitID)
        loaded?.onDidFinish = { [weak self] in
            Task { await self?.interstitialDidFinish() }
        }
        readyInterstitial = loaded
        isLoadingInterstitial = false
    }

    func didTapHideAdsForToday(from _: UIViewController) {
        // フェーズ 4 でリワード視聴を実装する
    }

    func presentInterstitialIfEligible(from rootViewController: UIViewController) {
        let eligibility = AdEligibility(
            isAdFree: isAdFree,
            hasPresentedInterstitialThisSession: hasPresentedInterstitialThisSession,
            elapsedSinceStart: now().timeIntervalSince(startDate),
            isInterstitialLoaded: readyInterstitial != nil
        )
        guard eligibility.canPresentInterstitial, let ad = readyInterstitial else { return }

        readyInterstitial = nil
        presentingInterstitial = ad
        hasPresentedInterstitialThisSession = true
        ad.present(from: rootViewController)
    }

    /// 閉じたあと次をプリロードする。同一セッションでは再提示しない
    func interstitialDidFinish() async {
        presentingInterstitial = nil
        await startLoadingIfNeeded()
    }
}

// MARK: - GoogleMobileAds

private final class GoogleInterstitialLoader: InterstitialAdHandling {
    func load(adUnitID: String) async -> (any InterstitialPresenting)? {
        do {
            let ad = try await InterstitialAd.load(with: adUnitID, request: Request())
            return GoogleInterstitialAd(ad: ad)
        } catch {
            return nil
        }
    }
}

private final class GoogleInterstitialAd: NSObject, InterstitialPresenting, FullScreenContentDelegate {
    private let ad: InterstitialAd
    var onDidFinish: (() -> Void)?

    init(ad: InterstitialAd) {
        self.ad = ad
        super.init()
        ad.fullScreenContentDelegate = self
    }

    func present(from rootViewController: UIViewController) {
        ad.present(from: rootViewController)
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onDidFinish?()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        onDidFinish?()
    }
}
