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
    @Published private(set) var canRequestRewarded: Bool
    @Published private(set) var rewardUnavailable = false
    @Published private(set) var adFreeRemaining: TimeInterval = 0

    private let interstitialAdUnitID: String
    private let rewardedAdUnitID: String
    private let loader: any InterstitialAdHandling
    private let rewardedLoader: any RewardedAdHandling
    private let store: AdFreeStore
    private let adFreeDuration: TimeInterval
    private let now: () -> Date
    private let startDate: Date

    private var readyInterstitial: (any InterstitialPresenting)?
    private var presentingInterstitial: (any InterstitialPresenting)?
    private var hasPresentedInterstitialThisSession = false
    private var isLoadingInterstitial = false

    private var readyRewarded: (any RewardedPresenting)?
    private var presentingRewarded: (any RewardedPresenting)?
    private var isLoadingRewarded = false
    private var rewardUnavailableClearTask: Task<Void, Never>?
    private var pendingReward: RewardedPurpose?
    private var pendingOnEarned: (() -> Void)?

    convenience init(
        interstitialAdUnitID: String,
        rewardedAdUnitID: String = "",
        now: @escaping () -> Date = Date.init,
        startDate: Date? = nil
    ) {
        self.init(
            interstitialAdUnitID: interstitialAdUnitID,
            rewardedAdUnitID: rewardedAdUnitID,
            loader: GoogleInterstitialLoader(),
            rewardedLoader: GoogleRewardedLoader(),
            store: AdFreeStore(),
            adFreeDuration: AdFreeStore.defaultDuration,
            now: now,
            startDate: startDate
        )
    }

    init(
        interstitialAdUnitID: String,
        rewardedAdUnitID: String = "",
        loader: any InterstitialAdHandling,
        rewardedLoader: any RewardedAdHandling,
        store: AdFreeStore,
        adFreeDuration: TimeInterval,
        now: @escaping () -> Date = Date.init,
        startDate: Date? = nil
    ) {
        self.interstitialAdUnitID = interstitialAdUnitID
        self.rewardedAdUnitID = rewardedAdUnitID
        self.loader = loader
        self.rewardedLoader = rewardedLoader
        self.store = store
        self.adFreeDuration = adFreeDuration
        self.now = now
        self.startDate = startDate ?? now()
        let adFree = store.isAdFree(at: self.startDate)
        self.isAdFree = adFree
        self.canRequestRewarded = !adFree
        self.adFreeRemaining = store.remaining(at: self.startDate)
    }

    func refreshAdFreeState() {
        let wasAdFree = isAdFree
        let current = now()
        isAdFree = store.isAdFree(at: current)
        adFreeRemaining = store.remaining(at: current)
        canRequestRewarded = !isAdFree
        if wasAdFree && !isAdFree {
            Task { [weak self] in await self?.startLoadingIfNeeded() }
        }
    }

    func startLoadingIfNeeded() async {
        refreshAdFreeState()
        if !isAdFree {
            await loadInterstitialIfNeeded()
        }
        await loadRewardedIfNeeded()
    }

    func didTapHideAdsForToday(from rootViewController: UIViewController) {
        presentRewarded(from: rootViewController, purpose: .adFree24h)
    }

    func presentRewarded(
        from rootViewController: UIViewController,
        purpose: RewardedPurpose,
        onEarned: (() -> Void)? = nil
    ) {
        if purpose == .adFree24h {
            refreshAdFreeState()
            guard !isAdFree else { return }
        }
        guard presentingRewarded == nil else { return }
        guard let ad = readyRewarded else {
            showRewardUnavailable()
            return
        }

        pendingReward = purpose
        pendingOnEarned = onEarned
        readyRewarded = nil
        presentingRewarded = ad
        ad.present(from: rootViewController)
    }

    func presentInterstitialIfEligible(from rootViewController: UIViewController) {
        refreshAdFreeState()
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

    func rewardedDidFinish() async {
        presentingRewarded = nil
        pendingReward = nil
        pendingOnEarned = nil
        await startLoadingIfNeeded()
    }

    private func handleEarnedReward() {
        let purpose = pendingReward
        let onEarned = pendingOnEarned
        pendingReward = nil
        pendingOnEarned = nil
        switch purpose {
        case .adFree24h:
            grantAdFree()
        case .extraMemberSetSlot:
            onEarned?()
        case nil:
            break
        }
    }

    private func grantAdFree() {
        let grantedAt = now()
        store.grant(from: grantedAt, duration: adFreeDuration)
        isAdFree = true
        canRequestRewarded = false
        adFreeRemaining = store.remaining(at: grantedAt)
        rewardUnavailable = false
    }

    private func showRewardUnavailable() {
        rewardUnavailable = true
        rewardUnavailableClearTask?.cancel()
        rewardUnavailableClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.rewardUnavailable = false
        }
    }

    private func loadInterstitialIfNeeded() async {
        guard !interstitialAdUnitID.isEmpty else { return }
        guard readyInterstitial == nil, presentingInterstitial == nil else { return }
        guard !isLoadingInterstitial else { return }

        isLoadingInterstitial = true
        let loaded = await loader.load(adUnitID: interstitialAdUnitID)
        loaded?.onDidFinish = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.interstitialDidFinish()
            }
        }
        readyInterstitial = loaded
        isLoadingInterstitial = false
    }

    private func loadRewardedIfNeeded() async {
        guard !rewardedAdUnitID.isEmpty else { return }
        guard readyRewarded == nil, presentingRewarded == nil else { return }
        guard !isLoadingRewarded else { return }

        isLoadingRewarded = true
        let loaded = await rewardedLoader.load(adUnitID: rewardedAdUnitID)
        loaded?.onDidEarnReward = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleEarnedReward()
            }
        }
        loaded?.onDidFinish = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.rewardedDidFinish()
            }
        }
        readyRewarded = loaded
        isLoadingRewarded = false
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
        Task { @MainActor [weak self] in
            self?.onDidFinish?()
        }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.onDidFinish?()
        }
    }
}

private final class GoogleRewardedLoader: RewardedAdHandling {
    func load(adUnitID: String) async -> (any RewardedPresenting)? {
        do {
            let ad = try await RewardedAd.load(with: adUnitID, request: Request())
            return GoogleRewardedAd(ad: ad)
        } catch {
            return nil
        }
    }
}

private final class GoogleRewardedAd: NSObject, RewardedPresenting, FullScreenContentDelegate {
    private let ad: RewardedAd
    var onDidEarnReward: (() -> Void)?
    var onDidFinish: (() -> Void)?

    init(ad: RewardedAd) {
        self.ad = ad
        super.init()
        ad.fullScreenContentDelegate = self
    }

    func present(from rootViewController: UIViewController) {
        ad.present(from: rootViewController) { [weak self] in
            Task { @MainActor [weak self] in
                self?.onDidEarnReward?()
            }
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            self?.onDidFinish?()
        }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.onDidFinish?()
        }
    }
}
