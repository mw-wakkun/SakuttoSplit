//
//  SakuttoSplitRouterTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import XCTest
@testable import SakuttoSplit

@MainActor
final class SakuttoSplitRouterTests: XCTestCase {

    func testAssembleModule_ReturnsConcreteViewHoldingPresenter() {
        let view = SakuttoSplitRouter.assembleModule()

        XCTAssertEqual(view.presenter.viewState.groups.count, 2)
        XCTAssertEqual(view.bannerAdUnitID, AdConfiguration.defaultBannerAdUnitID)
        XCTAssertFalse(view.bannerAdUnitID.isEmpty)
    }

    /// 新仕様: 組み立て結果は View ではなく presenter と空でない bannerAdUnitID
    func testAssembleModule_ReturnsPresenterAndNonEmptyBannerAdUnitID() {
        let module = SakuttoSplitRouter.assembleModule()

        XCTAssertFalse(module as Any is SakuttoSplitView)
        XCTAssertEqual(module.presenter.viewState.groups.count, 2)
        XCTAssertFalse(module.bannerAdUnitID.isEmpty)
        XCTAssertEqual(module.bannerAdUnitID, AdConfiguration.defaultBannerAdUnitID)
    }
}
