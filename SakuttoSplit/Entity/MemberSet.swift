//
//  MemberSet.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import Foundation

/// 名前付きの編成。グループと端数単位を持ち、総額・結果は持たない
struct MemberSet: Identifiable, Equatable, Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    let id: UUID
    var name: String
    var roundingUnit: RoundingUnit
    var groups: [AttendeeGroupDraft]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        roundingUnit: RoundingUnit,
        groups: [AttendeeGroupDraft],
        createdAt: Date = Date(),
        schemaVersion: Int = MemberSet.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.roundingUnit = roundingUnit
        self.groups = groups
        self.createdAt = createdAt
    }

    var isCurrentSchema: Bool {
        schemaVersion == Self.currentSchemaVersion
    }
}
