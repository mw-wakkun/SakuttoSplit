//
//  AdConfigurationTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import StoreKit
import XCTest
@testable import SakuttoSplit

final class AdConfigurationTests: XCTestCase {

    func testSelectsTestAdUnits_Debug_AlwaysUsesTestAds() {
        XCTAssertTrue(
            AdConfiguration.selectsTestAdUnits(
                isDebugBuild: true,
                distribution: .appStoreProduction
            )
        )
        XCTAssertTrue(
            AdConfiguration.selectsTestAdUnits(
                isDebugBuild: true,
                distribution: .testFlightOrUnknown
            )
        )
    }

    func testSelectsTestAdUnits_ReleaseTestFlight_UsesTestAds() {
        XCTAssertTrue(
            AdConfiguration.selectsTestAdUnits(
                isDebugBuild: false,
                distribution: .testFlightOrUnknown
            )
        )
    }

    func testSelectsTestAdUnits_ReleaseAppStore_UsesProductionAds() {
        XCTAssertFalse(
            AdConfiguration.selectsTestAdUnits(
                isDebugBuild: false,
                distribution: .appStoreProduction
            )
        )
    }

    func testDistribution_ProductionEnvironmentOnly_IsAppStore() {
        XCTAssertEqual(
            AdConfiguration.distribution(from: .production),
            .appStoreProduction
        )
        XCTAssertEqual(
            AdConfiguration.distribution(from: .sandbox),
            .testFlightOrUnknown
        )
        XCTAssertEqual(
            AdConfiguration.distribution(from: .xcode),
            .testFlightOrUnknown
        )
        XCTAssertEqual(
            AdConfiguration.distribution(from: nil),
            .testFlightOrUnknown
        )
    }

    func testResolvedUnitIDs_MatchSelection() async {
        let usesTestAdUnits = await AdConfiguration.resolvedUsesTestAdUnits()
        let configuration = await AdConfiguration.resolved()
        if usesTestAdUnits {
            XCTAssertEqual(configuration, AdConfiguration.googleSample)
        } else {
            XCTAssertEqual(configuration, AdConfiguration.production)
        }
        let bannerAdUnitID = await AdConfiguration.resolvedBannerAdUnitID()
        let interstitialAdUnitID = await AdConfiguration.resolvedInterstitialAdUnitID()
        let rewardedAdUnitID = await AdConfiguration.resolvedRewardedAdUnitID()
        XCTAssertEqual(bannerAdUnitID, configuration.bannerAdUnitID)
        XCTAssertEqual(interstitialAdUnitID, configuration.interstitialAdUnitID)
        XCTAssertEqual(rewardedAdUnitID, configuration.rewardedAdUnitID)
    }

    func testGoogleSampleUnitIDs_AreOfficialDemoIDs() {
        XCTAssertEqual(
            AdConfiguration.googleSampleBannerUnitID,
            "ca-app-pub-3940256099942544/2934735716"
        )
        XCTAssertEqual(
            AdConfiguration.googleSampleInterstitialUnitID,
            "ca-app-pub-3940256099942544/4411468910"
        )
        XCTAssertEqual(
            AdConfiguration.googleSampleRewardedUnitID,
            "ca-app-pub-3940256099942544/1712485313"
        )
    }

    func testProductionAdUnitIDs_AreNonEmptyReleaseIDs() {
        XCTAssertEqual(
            AdConfiguration.productionBannerAdUnitID,
            "ca-app-pub-9676260030977388/3738962239"
        )
        XCTAssertEqual(
            AdConfiguration.productionInterstitialAdUnitID,
            "ca-app-pub-9676260030977388/7047443390"
        )
        XCTAssertEqual(
            AdConfiguration.productionRewardedAdUnitID,
            "ca-app-pub-9676260030977388/1795116714"
        )
        XCTAssertTrue(AdConfiguration.productionBannerAdUnitID.hasPrefix("ca-app-pub-9676260030977388/"))
        XCTAssertTrue(AdConfiguration.productionInterstitialAdUnitID.hasPrefix("ca-app-pub-9676260030977388/"))
        XCTAssertTrue(AdConfiguration.productionRewardedAdUnitID.hasPrefix("ca-app-pub-9676260030977388/"))
    }
}
