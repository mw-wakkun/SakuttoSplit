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
    var groupName: String
    /// 展開時は 1 始まり。グループ 1 行のときは nil
    var displayNumber: Int?
    var amountPerPerson: Int
    var isPaid: Bool

    /// シェア文とテスト用。展開は `名前 番号`、非展開はグループ名
    var label: String {
        if let displayNumber {
            return "\(groupName) \(displayNumber)"
        }
        return groupName
    }

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
                groupName: name,
                displayNumber: shouldExpand ? index + 1 : nil,
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

    var progressStatus: CollectionProgressStatus {
        CollectionProgressStatus(seats: seats)
    }

    /// 妥当な会計のときだけ席を作る。済は席 ID で引き継ぎ、今いないキーは捨てる
    static func reconcile(
        groups: [AttendeeGroupDraft],
        results: [GroupCalculationResult],
        paidSeatKeys: Set<String>,
        expandMaxCount: Int
    ) -> CollectionState {
        let amounts = Dictionary(
            results.map { ($0.groupID, $0.amountPerPerson) },
            uniquingKeysWith: { _, last in last }
        )
        let seats = groups.flatMap { group in
            CollectionSeat.make(
                groupID: group.id,
                name: group.name,
                count: group.toDomain().count,
                amountPerPerson: amounts[group.id] ?? 0,
                expandMaxCount: expandMaxCount,
                paidSeatKeys: paidSeatKeys
            )
        }
        return CollectionState(seats: seats)
    }
}

/// 回収進捗の表示分岐。席が無いときは全員済にしない
enum CollectionProgressStatus: Equatable {
    case empty
    case inProgress(unpaidCount: Int, seatCount: Int)
    case allPaid(seatCount: Int)

    init(seats: [CollectionSeat]) {
        let unpaidCount = seats.reduce(into: 0) { count, seat in
            if !seat.isPaid { count += 1 }
        }
        self.init(unpaidCount: unpaidCount, seatCount: seats.count)
    }

    init(unpaidCount: Int, seatCount: Int) {
        if seatCount <= 0 {
            self = .empty
        } else if unpaidCount == 0 {
            self = .allPaid(seatCount: seatCount)
        } else {
            self = .inProgress(unpaidCount: unpaidCount, seatCount: seatCount)
        }
    }

    var paidCount: Int {
        switch self {
        case .empty:
            return 0
        case .inProgress(let unpaidCount, let seatCount):
            return seatCount - unpaidCount
        case .allPaid(let seatCount):
            return seatCount
        }
    }

    var seatCount: Int {
        switch self {
        case .empty:
            return 0
        case .inProgress(_, let seatCount), .allPaid(let seatCount):
            return seatCount
        }
    }
}
