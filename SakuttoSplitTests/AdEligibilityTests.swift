//
//  AdEligibilityTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import XCTest
@testable import SakuttoSplit

final class AdEligibilityTests: XCTestCase {

    func testCanShowBanner_WhenAdFree_IsFalse() {
        let eligibility = AdEligibility(
            isAdFree: true,
            hasPresentedInterstitialThisSession: false,
            elapsedSinceStart: 30,
            isInterstitialLoaded: true
        )

        XCTAssertFalse(eligibility.canShowBanner)
    }

    func testCanShowBanner_WhenNotAdFree_IsTrue() {
        let eligibility = AdEligibility(
            isAdFree: false,
            hasPresentedInterstitialThisSession: true,
            elapsedSinceStart: 0,
            isInterstitialLoaded: false
        )

        XCTAssertTrue(eligibility.canShowBanner)
    }

    func testCanPresentInterstitial_WhenAdFree_IsFalse() {
        let eligibility = eligibleInterstitial(isAdFree: true)

        XCTAssertFalse(eligibility.canPresentInterstitial)
    }

    func testCanPresentInterstitial_WhenAlreadyPresentedThisSession_IsFalse() {
        let eligibility = eligibleInterstitial(hasPresentedInterstitialThisSession: true)

        XCTAssertFalse(eligibility.canPresentInterstitial)
    }

    func testCanPresentInterstitial_WhenNotLoaded_IsFalse() {
        let eligibility = eligibleInterstitial(isInterstitialLoaded: false)

        XCTAssertFalse(eligibility.canPresentInterstitial)
    }

    func testCanPresentInterstitial_Elapsed14Seconds_IsFalse() {
        let eligibility = eligibleInterstitial(elapsedSinceStart: 14)

        XCTAssertFalse(eligibility.canPresentInterstitial)
    }

    func testCanPresentInterstitial_Elapsed15Seconds_IsTrue() {
        let eligibility = eligibleInterstitial(elapsedSinceStart: 15)

        XCTAssertTrue(eligibility.canPresentInterstitial)
    }

    func testCanPresentInterstitial_ElapsedJustBelow15Seconds_IsFalse() {
        let eligibility = eligibleInterstitial(
            elapsedSinceStart: AdEligibility.interstitialMinimumElapsedSeconds - 0.001
        )

        XCTAssertFalse(eligibility.canPresentInterstitial)
    }

    func testCanPresentInterstitial_AllConditionsMet_IsTrue() {
        let eligibility = eligibleInterstitial()

        XCTAssertTrue(eligibility.canPresentInterstitial)
        XCTAssertTrue(eligibility.canShowBanner)
    }

    private func eligibleInterstitial(
        isAdFree: Bool = false,
        hasPresentedInterstitialThisSession: Bool = false,
        elapsedSinceStart: TimeInterval = 30,
        isInterstitialLoaded: Bool = true
    ) -> AdEligibility {
        AdEligibility(
            isAdFree: isAdFree,
            hasPresentedInterstitialThisSession: hasPresentedInterstitialThisSession,
            elapsedSinceStart: elapsedSinceStart,
            isInterstitialLoaded: isInterstitialLoaded
        )
    }
}
