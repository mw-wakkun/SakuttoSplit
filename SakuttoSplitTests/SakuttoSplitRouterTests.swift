//
//  SakuttoSplitRouterTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI
import XCTest
@testable import SakuttoSplit

@MainActor
final class SakuttoSplitRouterTests: XCTestCase {

    func testAssembleModule_ReturnsPresenterAndNonEmptyBannerAdUnitID() {
        let module = SakuttoSplitRouter.assembleModule()

        XCTAssertEqual(module.presenter.viewState.groups.count, 2)
        XCTAssertFalse(module.adsController.isAdFree)
        XCTAssertFalse(module.bannerAdUnitID.isEmpty)
        XCTAssertEqual(module.bannerAdUnitID, AdConfiguration.defaultBannerAdUnitID)
        XCTAssertEqual(module.interstitialAdUnitID, AdConfiguration.defaultInterstitialAdUnitID)
        XCTAssertEqual(module.rewardedAdUnitID, AdConfiguration.defaultRewardedAdUnitID)
    }

    func testDefaultAdConfiguration_DebugTestIDsAreNonEmpty() {
        let config = AdConfiguration()

        XCTAssertFalse(config.bannerAdUnitID.isEmpty)
        #if DEBUG
        XCTAssertFalse(config.interstitialAdUnitID.isEmpty)
        XCTAssertFalse(config.rewardedAdUnitID.isEmpty)
        XCTAssertEqual(config.bannerAdUnitID, "ca-app-pub-3940256099942544/2934735716")
        XCTAssertEqual(config.interstitialAdUnitID, "ca-app-pub-3940256099942544/4411468910")
        XCTAssertEqual(config.rewardedAdUnitID, "ca-app-pub-3940256099942544/1712485313")
        #endif
    }

    func testProductionAdUnitIDs_BannerIsCurrentReleaseID() {
        XCTAssertEqual(
            AdConfiguration.productionBannerAdUnitID,
            "ca-app-pub-9676260030977388/3738962239"
        )
        XCTAssertTrue(AdConfiguration.productionBannerAdUnitID.hasPrefix("ca-app-pub-9676260030977388/"))
    }

    func testAssembleModule_UsesInjectedAdConfiguration() {
        let module = SakuttoSplitRouter.assembleModule(
            adConfiguration: StubAdConfiguration(
                bannerAdUnitID: "ca-app-pub-test/banner",
                interstitialAdUnitID: "ca-app-pub-test/interstitial",
                rewardedAdUnitID: "ca-app-pub-test/rewarded"
            )
        )

        XCTAssertEqual(module.bannerAdUnitID, "ca-app-pub-test/banner")
        XCTAssertEqual(module.interstitialAdUnitID, "ca-app-pub-test/interstitial")
        XCTAssertEqual(module.rewardedAdUnitID, "ca-app-pub-test/rewarded")
    }

    /// 組み立て後の presenter はジェネリック View に型推論で渡せる
    func testAssembleModule_PresenterTypeInfersGenericView() {
        let module = SakuttoSplitRouter.assembleModule()
        let view = SakuttoSplitView(
            presenter: module.presenter,
            adsController: module.adsController,
            bannerAdUnitID: module.bannerAdUnitID,
            isAdsSDKReady: false
        )

        XCTAssertEqual(view.presenter.viewState.groups.count, 2)
        XCTAssertEqual(view.bannerAdUnitID, module.bannerAdUnitID)
        XCTAssertFalse(view.isAdsSDKReady)
        XCTAssertFalse(view.adsController.isAdFree)
    }
}

private struct StubAdConfiguration: AdConfigurationProviding {
    let bannerAdUnitID: String
    let interstitialAdUnitID: String
    let rewardedAdUnitID: String
}
