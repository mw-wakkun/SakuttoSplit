//
//  CollectionSeat.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import Foundation

/// 回収ボードの席 ID。永続化キーは `"{groupID.uuidString}:{index}"`
struct CollectionSeatID: Hashable, Equatable, RawRepresentable {
    let groupID: UUID
    /// 同一グループ内。0 始まり。展開しないグループは 0 のみ
    let index: Int

    var rawValue: String {
        "\(groupID.uuidString):\(index)"
    }

    init(groupID: UUID, index: Int) {
        self.groupID = groupID
        self.index = index
    }

    init?(rawValue: String) {
        guard let separator = rawValue.lastIndex(of: ":") else { return nil }
        let uuidPart = String(rawValue[..<separator])
        let indexPart = String(rawValue[rawValue.index(after: separator)...])
        guard let groupID = UUID(uuidString: uuidPart),
              let index = Int(indexPart),
              index >= 0 else {
            return nil
        }
        self.groupID = groupID
        self.index = index
    }
}

/// 回収ボードの 1 行。金額はグループの 1 人あたり
struct CollectionSeat: Equatable, Identifiable {
    var id: CollectionSeatID
    var label: String
    var amountPerPerson: Int
    var isPaid: Bool

    /// 人数が上限以下なら席を展開する。超えたらグループ 1 行。済は席 ID で引き継ぐ
    static func make(
        groupID: UUID,
        name: String,
        count: Int,
        amountPerPerson: Int,
        expandMaxCount: Int,
        paidSeatKeys: Set<String> = []
    ) -> [CollectionSeat] {
        let shouldExpand = count <= expandMaxCount
        let seatCount = shouldExpand ? max(count, 0) : 1
        return (0..<seatCount).map { index in
            let id = CollectionSeatID(groupID: groupID, index: index)
            return CollectionSeat(
                id: id,
                label: shouldExpand ? "\(name) \(index + 1)" : name,
                amountPerPerson: amountPerPerson,
                isPaid: paidSeatKeys.contains(id.rawValue)
            )
        }
    }
}

/// 席の済/未済。計算の viewState とは独立する
struct CollectionState: Equatable {
    var seats: [CollectionSeat]

    static let empty = CollectionState(seats: [])

    var unpaidSeats: [CollectionSeat] {
        seats.filter { !$0.isPaid }
    }

    var paidSeatKeys: [String] {
        seats.filter(\.isPaid).map(\.id.rawValue)
    }
}
