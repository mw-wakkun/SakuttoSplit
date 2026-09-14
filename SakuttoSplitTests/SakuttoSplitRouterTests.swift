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
}
