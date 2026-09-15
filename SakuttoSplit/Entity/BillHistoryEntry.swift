//
//  BillHistoryEntry.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import Foundation

/// 日付付きの会計スナップショット。計算しない。snapshot は schema 2 のまま
struct BillHistoryEntry: Identifiable, Equatable, Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: UUID
    var savedAt: Date
    var snapshot: BillSnapshot

    init(
        id: UUID = UUID(),
        savedAt: Date,
        snapshot: BillSnapshot,
        schemaVersion: Int = BillHistoryEntry.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.savedAt = savedAt
        self.snapshot = snapshot
    }

    var isCurrentSchema: Bool {
        schemaVersion == Self.currentSchemaVersion
    }

    /// 回収ボードと同じ未払い人数。21 人以上のグループは席 1
    var unpaidCount: Int {
        let paidKeys = Set(snapshot.paidSeatKeys)
        let seats = snapshot.groups.flatMap { group in
            CollectionSeat.make(
                groupID: group.id,
                name: group.name,
                count: group.toDomain().count,
                amountPerPerson: 0,
                expandMaxCount: InputLimits.collectionExpandMaxCount,
                paidSeatKeys: paidKeys
            )
        }
        return seats.filter { !$0.isPaid }.count
    }

    /// 編成シートと同じプレビュー。例: `部長 1 / 一般 4 · 100円`
    var compositionPreview: String {
        MemberSet(
            name: "",
            roundingUnit: snapshot.roundingUnit,
            groups: snapshot.groups
        ).compositionPreview
    }

    /// 先頭のグループ ID 列が同じなら上書き。違えば先頭へ insert し上限で切る
    static func upserting(
        _ snapshot: BillSnapshot,
        into history: [BillHistoryEntry],
        now: Date = Date(),
        maxCount: Int = BillSessionStore.maxHistoryCount
    ) -> [BillHistoryEntry] {
        var history = history
        if let first = history.first,
           first.snapshot.groups.map(\.id) == snapshot.groups.map(\.id) {
            history[0].snapshot = snapshot
            history[0].savedAt = now
            return history
        }
        history.insert(
            BillHistoryEntry(savedAt: now, snapshot: snapshot),
            at: 0
        )
        if history.count > maxCount {
            history = Array(history.prefix(maxCount))
        }
        return history
    }
}
