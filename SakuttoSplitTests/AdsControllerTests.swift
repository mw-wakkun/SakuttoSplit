//
//  AdsControllerTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import UIKit
import XCTest
@testable import SakuttoSplit

@MainActor
final class AdsControllerTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AdsControllerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testStartLoadingIfNeeded_PassesInterstitialAdUnitID() async {
        let loader = StubInterstitialLoader(ad: FakeInterstitial())
        let controller = makeController(loader: loader)

        await controller.startLoadingIfNeeded()

        XCTAssertEqual(loader.loadCount, 1)
        XCTAssertEqual(loader.lastAdUnitID, "ca-app-pub-test/interstitial")
    }

    func testStartLoadingIfNeeded_EmptyAdUnitID_DoesNotLoad() async {
        let loader = StubInterstitialLoader(ad: FakeInterstitial())
        let controller = makeController(interstitialAdUnitID: "", loader: loader)

        await controller.startLoadingIfNeeded()

        XCTAssertEqual(loader.loadCount, 0)
    }

    func testStartLoadingIfNeeded_DoesNotPresentRewarded() async {
        let rewarded = FakeRewarded()
        let rewardedLoader = StubRewardedLoader(ad: rewarded)
        let controller = makeController(rewardedLoader: rewardedLoader)

        await controller.startLoadingIfNeeded()

        XCTAssertEqual(rewardedLoader.loadCount, 1)
        XCTAssertEqual(rewardedLoader.lastAdUnitID, "ca-app-pub-test/rewarded")
        XCTAssertEqual(rewarded.presentCallCount, 0)
        XCTAssertTrue(controller.canRequestRewarded)
    }

    func testPresent_WhenNotLoaded_DoesNotPresent() async {
        let interstitial = FakeInterstitial()
        let loader = StubInterstitialLoader(ad: nil)
        let controller = makeController(loader: loader, elapsed: 30)
        await controller.startLoadingIfNeeded()

        controller.presentInterstitialIfEligible(from: UIViewController())

        XCTAssertEqual(interstitial.presentCallCount, 0)
    }

    func testPresent_Before15Seconds_DoesNotPresent() async {
        let interstitial = FakeInterstitial()
        let loader = StubInterstitialLoader(ad: interstitial)
        let controller = makeController(loader: loader, elapsed: 14)
        await controller.startLoadingIfNeeded()

        controller.presentInterstitialIfEligible(from: UIViewController())

        XCTAssertEqual(interstitial.presentCallCount, 0)
    }

    func testPresent_At15Seconds_PresentsOncePerSession() async {
        let interstitial = FakeInterstitial()
        let loader = StubInterstitialLoader(ad: interstitial)
        let controller = makeController(loader: loader, elapsed: 15)
        await controller.startLoadingIfNeeded()
        let root = UIViewController()

        controller.presentInterstitialIfEligible(from: root)
        controller.presentInterstitialIfEligible(from: root)

        XCTAssertEqual(interstitial.presentCallCount, 1)
        XCTAssertEqual(interstitial.lastRoot, root)
    }

    func testPresent_SecondTimeThisSession_DoesNotPresentEvenIfReloaded() async {
        let first = FakeInterstitial()
        let second = FakeInterstitial()
        let loader = StubInterstitialLoader(ad: first)
        let controller = makeController(loader: loader, elapsed: 20)
        await controller.startLoadingIfNeeded()

        controller.presentInterstitialIfEligible(from: UIViewController())
        loader.ad = second
        await controller.interstitialDidFinish()
        controller.presentInterstitialIfEligible(from: UIViewController())

        XCTAssertEqual(first.presentCallCount, 1)
        XCTAssertEqual(second.presentCallCount, 0)
        XCTAssertEqual(loader.loadCount, 2)
    }

    func testPresent_WhenAdFree_DoesNotPresent() async {
        let interstitial = FakeInterstitial()
        let loader = StubInterstitialLoader(ad: interstitial)
        let store = AdFreeStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_000)
        store.grant(from: start, duration: 3_600)
        let controller = makeController(loader: loader, elapsed: 30, store: store, start: start)
        await controller.startLoadingIfNeeded()

        controller.presentInterstitialIfEligible(from: UIViewController())

        XCTAssertTrue(controller.isAdFree)
        XCTAssertEqual(interstitial.presentCallCount, 0)
        XCTAssertEqual(loader.loadCount, 0)
    }

    func testDidTapHideAdsForToday_WhenNotLoaded_SetsUnavailableAndDoesNotGrant() async {
        let rewardedLoader = StubRewardedLoader(ad: nil)
        let controller = makeController(rewardedLoader: rewardedLoader)
        await controller.startLoadingIfNeeded()

        controller.didTapHideAdsForToday(from: UIViewController())

        XCTAssertTrue(controller.rewardUnavailable)
        XCTAssertFalse(controller.isAdFree)
        XCTAssertNil(AdFreeStore(defaults: defaults).adFreeUntil)
    }

    func testDidTapHideAdsForToday_OnEarnReward_GrantsAdFree() async {
        let rewarded = FakeRewarded()
        let rewardedLoader = StubRewardedLoader(ad: rewarded)
        let duration: TimeInterval = 120
        let controller = makeController(rewardedLoader: rewardedLoader, adFreeDuration: duration)
        await controller.startLoadingIfNeeded()
        let root = UIViewController()

        controller.didTapHideAdsForToday(from: root)
        XCTAssertEqual(rewarded.presentCallCount, 1)
        XCTAssertFalse(controller.isAdFree)

        rewarded.onDidEarnReward?()

        XCTAssertTrue(controller.isAdFree)
        XCTAssertFalse(controller.canRequestRewarded)
        XCTAssertEqual(controller.adFreeRemaining, duration)
        XCTAssertEqual(
            AdFreeStore(defaults: defaults).adFreeUntil,
            Date(timeIntervalSince1970: 1_000).addingTimeInterval(30 + duration)
        )
    }

    func testDidTapHideAdsForToday_DismissWithoutReward_DoesNotGrant() async {
        let rewarded = FakeRewarded()
        let rewardedLoader = StubRewardedLoader(ad: rewarded)
        let controller = makeController(rewardedLoader: rewardedLoader)
        await controller.startLoadingIfNeeded()

        controller.didTapHideAdsForToday(from: UIViewController())
        rewarded.onDidFinish?()
        await controller.rewardedDidFinish()

        XCTAssertFalse(controller.isAdFree)
        XCTAssertNil(AdFreeStore(defaults: defaults).adFreeUntil)
        XCTAssertEqual(rewarded.presentCallCount, 1)
    }

    func testPresentRewarded_AdFree24h_OnEarn_DoesNotInvokeOnEarned() async {
        let rewarded = FakeRewarded()
        let rewardedLoader = StubRewardedLoader(ad: rewarded)
        let controller = makeController(rewardedLoader: rewardedLoader)
        await controller.startLoadingIfNeeded()
        var onEarnedCount = 0

        controller.presentRewarded(from: UIViewController(), purpose: .adFree24h) {
            onEarnedCount += 1
        }
        rewarded.onDidEarnReward?()

        XCTAssertEqual(onEarnedCount, 0)
        XCTAssertTrue(controller.isAdFree)
    }

    func testPresentRewarded_ExtraSlot_OnEarn_CallsOnEarned_DoesNotGrantAdFree() async {
        let rewarded = FakeRewarded()
        let rewardedLoader = StubRewardedLoader(ad: rewarded)
        let controller = makeController(rewardedLoader: rewardedLoader)
        await controller.startLoadingIfNeeded()
        var onEarnedCount = 0

        controller.presentRewarded(from: UIViewController(), purpose: .extraMemberSetSlot) {
            onEarnedCount += 1
        }
        rewarded.onDidEarnReward?()

        XCTAssertEqual(rewarded.presentCallCount, 1)
        XCTAssertEqual(onEarnedCount, 1)
        XCTAssertFalse(controller.isAdFree)
        XCTAssertNil(AdFreeStore(defaults: defaults).adFreeUntil)
    }

    func testPresentRewarded_ExtraSlot_DismissWithoutReward_DoesNotCallOnEarned() async {
        let rewarded = FakeRewarded()
        let rewardedLoader = StubRewardedLoader(ad: rewarded)
        let controller = makeController(rewardedLoader: rewardedLoader)
        await controller.startLoadingIfNeeded()
        var onEarnedCount = 0

        controller.presentRewarded(from: UIViewController(), purpose: .extraMemberSetSlot) {
            onEarnedCount += 1
        }
        rewarded.onDidFinish?()
        await controller.rewardedDidFinish()

        XCTAssertEqual(onEarnedCount, 0)
        XCTAssertFalse(controller.isAdFree)
        XCTAssertNil(AdFreeStore(defaults: defaults).adFreeUntil)
    }

    func testPresentRewarded_ExtraSlot_WhenAdFree_StillPresents_DoesNotExtendAdFree() async {
        let rewarded = FakeRewarded()
        let rewardedLoader = StubRewardedLoader(ad: rewarded)
        let store = AdFreeStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_000)
        let duration: TimeInterval = 3_600
        store.grant(from: start, duration: duration)
        let until = store.adFreeUntil
        let controller = makeController(
            rewardedLoader: rewardedLoader,
            store: store,
            start: start
        )
        await controller.startLoadingIfNeeded()
        var onEarnedCount = 0

        XCTAssertTrue(controller.isAdFree)
        controller.presentRewarded(from: UIViewController(), purpose: .extraMemberSetSlot) {
            onEarnedCount += 1
        }
        rewarded.onDidEarnReward?()

        XCTAssertEqual(rewarded.presentCallCount, 1)
        XCTAssertEqual(onEarnedCount, 1)
        XCTAssertTrue(controller.isAdFree)
        XCTAssertEqual(store.adFreeUntil, until)
    }

    func testPresentRewarded_WhenAlreadyPresenting_IgnoresSecond() async {
        let rewarded = FakeRewarded()
        let rewardedLoader = StubRewardedLoader(ad: rewarded)
        let controller = makeController(rewardedLoader: rewardedLoader)
        await controller.startLoadingIfNeeded()

        controller.presentRewarded(from: UIViewController(), purpose: .extraMemberSetSlot)
        controller.didTapHideAdsForToday(from: UIViewController())

        XCTAssertEqual(rewarded.presentCallCount, 1)
        XCTAssertFalse(controller.isAdFree)
    }

    func testPresentRewarded_ExtraSlot_WhenNotLoaded_SetsUnavailable() async {
        let rewardedLoader = StubRewardedLoader(ad: nil)
        let controller = makeController(rewardedLoader: rewardedLoader)
        await controller.startLoadingIfNeeded()
        var onEarnedCount = 0

        controller.presentRewarded(from: UIViewController(), purpose: .extraMemberSetSlot) {
            onEarnedCount += 1
        }

        XCTAssertTrue(controller.rewardUnavailable)
        XCTAssertEqual(onEarnedCount, 0)
        XCTAssertFalse(controller.isAdFree)
    }

    func testStartLoadingIfNeeded_WhenAdFree_LoadsRewardedNotInterstitial() async {
        let interstitialLoader = StubInterstitialLoader(ad: FakeInterstitial())
        let rewardedLoader = StubRewardedLoader(ad: FakeRewarded())
        let store = AdFreeStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_000)
        store.grant(from: start, duration: 3_600)
        let controller = makeController(
            loader: interstitialLoader,
            rewardedLoader: rewardedLoader,
            store: store,
            start: start
        )

        await controller.startLoadingIfNeeded()

        XCTAssertTrue(controller.isAdFree)
        XCTAssertEqual(interstitialLoader.loadCount, 0)
        XCTAssertEqual(rewardedLoader.loadCount, 1)
    }

    func testAdFree_ExpiresAfterInjectedDuration_AllowsBannerAgain() async {
        let rewarded = FakeRewarded()
        var now = Date(timeIntervalSince1970: 1_000)
        let start = now
        let duration: TimeInterval = 10
        let controller = AdsController(
            interstitialAdUnitID: "ca-app-pub-test/interstitial",
            rewardedAdUnitID: "ca-app-pub-test/rewarded",
            loader: StubInterstitialLoader(ad: FakeInterstitial()),
            rewardedLoader: StubRewardedLoader(ad: rewarded),
            store: AdFreeStore(defaults: defaults),
            adFreeDuration: duration,
            now: { now },
            startDate: start
        )
        await controller.startLoadingIfNeeded()
        controller.didTapHideAdsForToday(from: UIViewController())
        rewarded.onDidEarnReward?()
        XCTAssertTrue(controller.isAdFree)
        XCTAssertEqual(AdBannerSlot.height(isFocused: false, isAdFree: controller.isAdFree), 0)

        now = start.addingTimeInterval(duration)
        controller.refreshAdFreeState()

        XCTAssertFalse(controller.isAdFree)
        XCTAssertTrue(controller.canRequestRewarded)
        XCTAssertEqual(AdBannerSlot.height(isFocused: false, isAdFree: controller.isAdFree), 50)
    }

    private func makeController(
        interstitialAdUnitID: String = "ca-app-pub-test/interstitial",
        loader: StubInterstitialLoader? = nil,
        rewardedLoader: StubRewardedLoader? = nil,
        elapsed: TimeInterval = 30,
        store: AdFreeStore? = nil,
        adFreeDuration: TimeInterval = 24 * 60 * 60,
        start: Date = Date(timeIntervalSince1970: 1_000)
    ) -> AdsController {
        AdsController(
            interstitialAdUnitID: interstitialAdUnitID,
            rewardedAdUnitID: "ca-app-pub-test/rewarded",
            loader: loader ?? StubInterstitialLoader(ad: FakeInterstitial()),
            rewardedLoader: rewardedLoader ?? StubRewardedLoader(ad: nil),
            store: store ?? AdFreeStore(defaults: defaults),
            adFreeDuration: adFreeDuration,
            now: { start.addingTimeInterval(elapsed) },
            startDate: start
        )
    }
}

@MainActor
private final class FakeInterstitial: InterstitialPresenting {
    var onDidFinish: (() -> Void)?
    private(set) var presentCallCount = 0
    private(set) var lastRoot: UIViewController?

    func present(from rootViewController: UIViewController) {
        presentCallCount += 1
        lastRoot = rootViewController
    }
}

@MainActor
private final class StubInterstitialLoader: InterstitialAdHandling {
    var ad: FakeInterstitial?
    private(set) var loadCount = 0
    private(set) var lastAdUnitID: String?

    init(ad: FakeInterstitial?) {
        self.ad = ad
    }

    func load(adUnitID: String) async -> (any InterstitialPresenting)? {
        loadCount += 1
        lastAdUnitID = adUnitID
        return ad
    }
}

@MainActor
private final class FakeRewarded: RewardedPresenting {
    var onDidEarnReward: (() -> Void)?
    var onDidFinish: (() -> Void)?
    private(set) var presentCallCount = 0
    private(set) var lastRoot: UIViewController?

    func present(from rootViewController: UIViewController) {
        presentCallCount += 1
        lastRoot = rootViewController
    }
}

@MainActor
private final class StubRewardedLoader: RewardedAdHandling {
    var ad: FakeRewarded?
    private(set) var loadCount = 0
    private(set) var lastAdUnitID: String?

    init(ad: FakeRewarded?) {
        self.ad = ad
    }

    func load(adUnitID: String) async -> (any RewardedPresenting)? {
        loadCount += 1
        lastAdUnitID = adUnitID
        return ad
    }
}
