//
//  ArchitectureBoundaryTests.swift
//  SakuttoSplitTests
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import XCTest

/// VIPER 境界と永続化キーの置き場所をソースで固定する。SDK / 通知 Center は叩かない
final class ArchitectureBoundaryTests: XCTestCase {

    func testUserNotificationsImport_IsOnlyInUnpaidReminderScheduler() throws {
        let offenders = try filesMatching { url, source in
            url.lastPathComponent != "UnpaidReminderScheduler.swift"
                && containsImport(source, module: "UserNotifications")
        }

        XCTAssertTrue(
            offenders.isEmpty,
            "UserNotifications is only allowed in UnpaidReminderScheduler.swift: \(names(of: offenders))"
        )
    }

    func testGoogleMobileAdsImport_IsOnlyInAllowedFiles() throws {
        let allowed: Set<String> = [
            "SakuttoSplitApp.swift",
            "AdBannerView.swift",
            "AdsController.swift"
        ]
        let offenders = try filesMatching { url, source in
            !allowed.contains(url.lastPathComponent)
                && containsImport(source, module: "GoogleMobileAds")
        }

        XCTAssertTrue(
            offenders.isEmpty,
            "GoogleMobileAds is only allowed in App / AdBannerView / AdsController: \(names(of: offenders))"
        )
    }

    func testSessionPersistenceKeyLiterals_AreOnlyInBillSessionStore() throws {
        let keys = [
            "session.billHistory",
            "session.memberSetOfferConsumed",
            "session.didPromptUnpaidReminder"
        ]
        let offenders = try filesMatching { url, source in
            url.lastPathComponent != "BillSessionStore.swift"
                && keys.contains { source.contains("\"\($0)\"") }
        }

        XCTAssertTrue(
            offenders.isEmpty,
            "session.* keys belong in BillSessionStore.swift: \(names(of: offenders))"
        )
    }

    func testUnpaidReminderThreeHourDelay_IsOnlyInUnpaidReminderSchedule() throws {
        let offenders = try filesMatching { url, source in
            url.lastPathComponent != "UnpaidReminderSchedule.swift"
                && source.contains("3 * 60 * 60")
        }

        XCTAssertTrue(
            offenders.isEmpty,
            "3-hour fire delay belongs in UnpaidReminderSchedule.swift: \(names(of: offenders))"
        )
    }

    private func containsImport(_ source: String, module: String) -> Bool {
        source.contains("import \(module)")
    }

    private func names(of urls: [URL]) -> String {
        urls.map(\.lastPathComponent).sorted().joined(separator: ", ")
    }

    private func filesMatching(_ predicate: (URL, String) -> Bool) throws -> [URL] {
        try productionSwiftFiles().compactMap { url in
            let source = try String(contentsOf: url, encoding: .utf8)
            return predicate(url, source) ? url : nil
        }
    }

    private func productionSwiftFiles() throws -> [URL] {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sources = testsDir.deletingLastPathComponent().appendingPathComponent("SakuttoSplit")
        guard FileManager.default.fileExists(atPath: sources.path) else {
            throw XCTSkip("SakuttoSplit sources were not found at \(sources.path)")
        }
        guard let enumerator = FileManager.default.enumerator(
            at: sources,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw XCTSkip("Could not enumerate \(sources.path)")
        }

        var files: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            files.append(url)
        }
        XCTAssertFalse(files.isEmpty, "expected production Swift files under SakuttoSplit/")
        return files
    }
}
