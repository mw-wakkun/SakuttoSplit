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
        let controller = makeController(loader: loader, elapsed: 30, isAdFree: true)
        await controller.startLoadingIfNeeded()

        controller.presentInterstitialIfEligible(from: UIViewController())

        XCTAssertEqual(interstitial.presentCallCount, 0)
    }

    private func makeController(
        interstitialAdUnitID: String = "ca-app-pub-test/interstitial",
        loader: StubInterstitialLoader,
        elapsed: TimeInterval = 30,
        isAdFree: Bool = false
    ) -> AdsController {
        let start = Date(timeIntervalSince1970: 1_000)
        return AdsController(
            interstitialAdUnitID: interstitialAdUnitID,
            loader: loader,
            now: { start.addingTimeInterval(elapsed) },
            startDate: start,
            isAdFree: isAdFree
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
