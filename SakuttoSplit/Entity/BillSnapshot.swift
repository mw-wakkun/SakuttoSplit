//
//  BillSnapshot.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import Foundation

/// 会計入力のスナップショット。結果・シェア文は持たない（復元時に再計算する）
struct BillSnapshot: Equatable, Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var totalAmountText: String
    var roundingUnit: RoundingUnit
    var groups: [AttendeeGroupDraft]

    init(
        totalAmountText: String,
        roundingUnit: RoundingUnit,
        groups: [AttendeeGroupDraft],
        schemaVersion: Int = BillSnapshot.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.totalAmountText = totalAmountText
        self.roundingUnit = roundingUnit
        self.groups = groups
    }

    var isCurrentSchema: Bool {
        schemaVersion == Self.currentSchemaVersion
    }
}
