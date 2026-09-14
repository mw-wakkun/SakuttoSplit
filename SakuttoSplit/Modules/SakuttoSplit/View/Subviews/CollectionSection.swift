//
//  CollectionSection.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import SwiftUI

/// 回収ボード。メインの sticky シェアとは別セクション。資格判定は Presenter が渡す
struct CollectionSection: View {
    let seats: [CollectionSeat]
    let unpaidShareText: String
    let isUnpaidShareEnabled: Bool
    var onToggle: (CollectionSeatID) -> Void

    private var unpaidCount: Int {
        seats.filter { !$0.isPaid }.count
    }

    var body: some View {
        Section("section.collection") {
            ForEach(seats) { seat in
                CollectionSeatRow(seat: seat, onToggle: onToggle)
            }

            progressRow

            UnpaidShareButton(shareText: unpaidShareText, isEnabled: isUnpaidShareEnabled)
        }
    }

    @ViewBuilder
    private var progressRow: some View {
        if unpaidCount == 0 {
            Text("collection.all_paid")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Text("collection.progress \(unpaidCount) \(seats.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// 席 1 行。チェック・ラベル・1 人あたり金額
private struct CollectionSeatRow: View {
    let seat: CollectionSeat
    var onToggle: (CollectionSeatID) -> Void

    var body: some View {
        Toggle(isOn: toggleBinding) {
            HStack {
                seatLabel
                Spacer()
                Text("result.per_person \(seat.amountPerPerson)")
            }
        }
    }

    @ViewBuilder
    private var seatLabel: some View {
        if let displayNumber = seat.displayNumber {
            Text("collection.seat_label \(seat.groupName) \(displayNumber)")
        } else {
            Text(seat.groupName)
        }
    }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { seat.isPaid },
            set: { newValue in
                if newValue != seat.isPaid {
                    onToggle(seat.id)
                }
            }
        )
    }
}

/// 未払い再シェア。緑背景にしない。ShareResultButton には相乗りしない
struct UnpaidShareButton: View {
    let shareText: String
    let isEnabled: Bool

    var body: some View {
        ShareLink(item: shareText) {
            Text("collection.share_unpaid")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

#Preview("few seats") {
    Form {
        CollectionSection(
            seats: collectionPreviewSeats(paidIndexes: [1]),
            unpaidShareText: "🍻 未払いのお願い 🍻",
            isUnpaidShareEnabled: true,
            onToggle: { _ in }
        )
    }
}

#Preview("all paid") {
    Form {
        CollectionSection(
            seats: collectionPreviewSeats(paidIndexes: [0, 1, 2]),
            unpaidShareText: "",
            isUnpaidShareEnabled: false,
            onToggle: { _ in }
        )
    }
}

private func collectionPreviewSeats(paidIndexes: Set<Int>) -> [CollectionSeat] {
    let groupID = UUID()
    return (0..<3).map { index in
        CollectionSeat(
            id: CollectionSeatID(groupID: groupID, index: index),
            groupName: "一般",
            displayNumber: index + 1,
            amountPerPerson: 6200,
            isPaid: paidIndexes.contains(index)
        )
    }
}
