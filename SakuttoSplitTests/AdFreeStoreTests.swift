//
//  AdFreeStoreTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import XCTest
@testable import SakuttoSplit

final class AdFreeStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AdFreeStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testIsAdFree_WhenNothingGranted_IsFalse() {
        let store = AdFreeStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertFalse(store.isAdFree(at: now))
        XCTAssertEqual(store.remaining(at: now), 0)
        XCTAssertNil(store.adFreeUntil)
    }

    func testGrant_MakesIsAdFreeTrueUntilDurationElapses() {
        let store = AdFreeStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_000)
        let duration: TimeInterval = 60

        store.grant(from: now, duration: duration)

        XCTAssertEqual(store.adFreeUntil, now.addingTimeInterval(duration))
        XCTAssertTrue(store.isAdFree(at: now))
        XCTAssertTrue(store.isAdFree(at: now.addingTimeInterval(59)))
        XCTAssertFalse(store.isAdFree(at: now.addingTimeInterval(60)))
        XCTAssertEqual(store.remaining(at: now), 60)
        XCTAssertEqual(store.remaining(at: now.addingTimeInterval(60)), 0)
    }

    func testHours_RoundsUpAndHasMinimumOne() {
        XCTAssertEqual(AdFreeRemaining.hours(remaining: 1), 1)
        XCTAssertEqual(AdFreeRemaining.hours(remaining: 3600), 1)
        XCTAssertEqual(AdFreeRemaining.hours(remaining: 3601), 2)
        XCTAssertEqual(AdFreeRemaining.hours(remaining: 24 * 3600), 24)
    }
}
