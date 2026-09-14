//
//  AdBannerSlotTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import XCTest
@testable import SakuttoSplit

final class AdBannerSlotTests: XCTestCase {

    func testHeight_WhenFocused_IsZero_EvenIfSDKReady() {
        XCTAssertEqual(AdBannerSlot.height(isFocused: true, isAdFree: false), 0)
        XCTAssertFalse(
            AdBannerSlot.showsLoadedBanner(
                isAdsSDKReady: true,
                isFocused: true,
                isAdFree: false
            )
        )
    }

    func testHeight_WhenUnfocusedAndNotAdFree_IsPlaceholder_EvenIfSDKNotReady() {
        XCTAssertEqual(AdBannerSlot.height(isFocused: false, isAdFree: false), 50)
        XCTAssertFalse(
            AdBannerSlot.showsLoadedBanner(
                isAdsSDKReady: false,
                isFocused: false,
                isAdFree: false
            )
        )
    }

    func testShowsLoadedBanner_WhenSDKReadyUnfocusedAndNotAdFree() {
        XCTAssertEqual(AdBannerSlot.height(isFocused: false, isAdFree: false), 50)
        XCTAssertTrue(
            AdBannerSlot.showsLoadedBanner(
                isAdsSDKReady: true,
                isFocused: false,
                isAdFree: false
            )
        )
    }

    func testHeight_WhenAdFree_IsZero_AndDoesNotLoad() {
        XCTAssertEqual(AdBannerSlot.height(isFocused: false, isAdFree: true), 0)
        XCTAssertFalse(
            AdBannerSlot.showsLoadedBanner(
                isAdsSDKReady: true,
                isFocused: false,
                isAdFree: true
            )
        )
    }

    func testShowsLoadedBanner_WhenSDKNotReadyAndFocused_IsFalse() {
        XCTAssertFalse(
            AdBannerSlot.showsLoadedBanner(
                isAdsSDKReady: false,
                isFocused: true,
                isAdFree: false
            )
        )
        XCTAssertEqual(AdBannerSlot.height(isFocused: true, isAdFree: false), 0)
    }
}
