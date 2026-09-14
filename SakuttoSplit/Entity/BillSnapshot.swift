//
//  BillSnapshot.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import Foundation

/// 会計入力のスナップショット。結果・シェア文は持たない（復元時に再計算する）
struct BillSnapshot: Equatable, Codable {
    static let currentSchemaVersion = 2
    static let oldestReadableSchemaVersion = 1

    var schemaVersion: Int
    var totalAmountText: String
    var roundingUnit: RoundingUnit
    var groups: [AttendeeGroupDraft]
    /// 済の席 ID。未払いは載せない。schema 1 には無い
    var paidSeatKeys: [String]

    init(
        totalAmountText: String,
        roundingUnit: RoundingUnit,
        groups: [AttendeeGroupDraft],
        paidSeatKeys: [String] = [],
        schemaVersion: Int = BillSnapshot.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.totalAmountText = totalAmountText
        self.roundingUnit = roundingUnit
        self.groups = groups
        self.paidSeatKeys = paidSeatKeys
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        totalAmountText = try container.decode(String.self, forKey: .totalAmountText)
        roundingUnit = try container.decode(RoundingUnit.self, forKey: .roundingUnit)
        groups = try container.decode([AttendeeGroupDraft].self, forKey: .groups)
        paidSeatKeys = try container.decodeIfPresent([String].self, forKey: .paidSeatKeys) ?? []
    }

    var isCurrentSchema: Bool {
        schemaVersion == Self.currentSchemaVersion
    }

    /// 読み込みは 1...current。schema 1 の lastBill を落としてはいけない
    var isReadableSchema: Bool {
        (Self.oldestReadableSchemaVersion...Self.currentSchemaVersion).contains(schemaVersion)
    }
}
