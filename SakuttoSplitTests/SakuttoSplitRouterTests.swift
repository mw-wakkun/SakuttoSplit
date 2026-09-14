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
        XCTAssertFalse(module.bannerAdUnitID.isEmpty)
        XCTAssertEqual(module.bannerAdUnitID, AdConfiguration.defaultBannerAdUnitID)
    }

    func testAssembleModule_UsesInjectedAdConfiguration() {
        let module = SakuttoSplitRouter.assembleModule(
            adConfiguration: StubAdConfiguration(bannerAdUnitID: "ca-app-pub-test/injected")
        )

        XCTAssertEqual(module.bannerAdUnitID, "ca-app-pub-test/injected")
    }

    /// 組み立て後の presenter はジェネリック View に型推論で渡せる
    func testAssembleModule_PresenterTypeInfersGenericView() {
        let module = SakuttoSplitRouter.assembleModule()
        let view = SakuttoSplitView(
            presenter: module.presenter,
            bannerAdUnitID: module.bannerAdUnitID,
            isAdsSDKReady: false
        )

        XCTAssertEqual(view.presenter.viewState.groups.count, 2)
        XCTAssertEqual(view.bannerAdUnitID, module.bannerAdUnitID)
        XCTAssertFalse(view.isAdsSDKReady)
    }
}

private struct StubAdConfiguration: AdConfigurationProviding {
    let bannerAdUnitID: String
}
