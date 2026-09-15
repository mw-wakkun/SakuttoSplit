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

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: AdFreeStore.adFreeUntilKey)
    }

    func testAssembleModule_DefersAdUnitIDsUntilRuntimeResolution() {
        let module = SakuttoSplitRouter.assembleModule()

        XCTAssertEqual(module.presenter.viewState.groups.count, 2)
        XCTAssertFalse(module.adsController.isAdFree)
        XCTAssertTrue(module.bannerAdUnitID.isEmpty)
        XCTAssertTrue(module.interstitialAdUnitID.isEmpty)
        XCTAssertTrue(module.rewardedAdUnitID.isEmpty)
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
        XCTAssertEqual(view.isAdsSDKReady, false)
        XCTAssertFalse(view.adsController.isAdFree)
        XCTAssertTrue(module.presenter.reminderScheduler is UnpaidReminderScheduler)
    }
}

private struct StubAdConfiguration: AdConfigurationProviding {
    let bannerAdUnitID: String
    let interstitialAdUnitID: String
    let rewardedAdUnitID: String
}
