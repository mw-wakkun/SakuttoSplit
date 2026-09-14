//
//  InfoPlistAdsTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import XCTest
@testable import SakuttoSplit

final class InfoPlistAdsTests: XCTestCase {

    func testGADApplicationIdentifier_IsUnchanged() {
        let appID = appInfo["GADApplicationIdentifier"] as? String
        XCTAssertEqual(appID, "ca-app-pub-9676260030977388~1564525389")
    }

    func testSKAdNetworkItems_IncludesGoogleAndMediationBuyers() {
        let items = appInfo["SKAdNetworkItems"] as? [[String: String]]
        let identifiers = items?.compactMap { $0["SKAdNetworkIdentifier"] } ?? []

        XCTAssertTrue(identifiers.contains("cstr6suwn9.skadnetwork"))
        XCTAssertGreaterThanOrEqual(identifiers.count, 50)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
    }

    func testUserTrackingUsageDescription_IsNotPresent() {
        XCTAssertNil(appInfo["NSUserTrackingUsageDescription"])
    }

    private var appInfo: [String: Any] {
        let bundle = Bundle(identifier: "io.github.mw-wakkun.SakuttoSplit") ?? Bundle.main
        return bundle.infoDictionary ?? [:]
    }
}
