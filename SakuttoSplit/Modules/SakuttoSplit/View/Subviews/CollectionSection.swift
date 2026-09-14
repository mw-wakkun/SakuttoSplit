//
//  CollectionSection.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import SwiftUI
import UIKit

/// 回収ボードの中身。`Section` は親の Form が開く。資格判定は Presenter が渡す
struct CollectionSection: View {
    let seats: [CollectionSeat]
    let unpaidShareText: String
    let isUnpaidShareEnabled: Bool
    var onToggle: (CollectionSeatID) -> Void
    var onMarkGroupPaid: (UUID) -> Void
    @State private var haptics = CollectionHaptics()

    var body: some View {
        let unpaidCount = seats.reduce(into: 0) { count, seat in
            if !seat.isPaid { count += 1 }
        }
        let paidFraction = seats.isEmpty ? 0.0 : Double(seats.count - unpaidCount) / Double(seats.count)

        ForEach(seatGroups) { group in
            ForEach(group.seats) { seat in
                CollectionSeatRow(seat: seat) {
                    toggleSeat(seat)
                }
            }

            if group.seats.count >= 2 {
                Button("collection.mark_group_paid") {
                    markGroupPaid(group.groupID)
                }
            }
        }

        progressRow(unpaidCount: unpaidCount, paidFraction: paidFraction)

        UnpaidShareButton(shareText: unpaidShareText, isEnabled: isUnpaidShareEnabled)
    }

    @ViewBuilder
    private func progressRow(unpaidCount: Int, paidFraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: paidFraction)
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

    private var seatGroups: [SeatGroup] {
        let grouped = Dictionary(grouping: seats, by: \.id.groupID)
        var seen = Set<UUID>()
        let order = seats.compactMap { seat -> UUID? in
            seen.insert(seat.id.groupID).inserted ? seat.id.groupID : nil
        }
        return order.map { SeatGroup(groupID: $0, seats: grouped[$0] ?? []) }
    }

    private func toggleSeat(_ seat: CollectionSeat) {
        let groupSeats = seats.filter { $0.id.groupID == seat.id.groupID }
        let unpaidInGroup = groupSeats.filter { !$0.isPaid }
        let willCompleteGroup = !seat.isPaid && unpaidInGroup.count == 1
        onToggle(seat.id)
        haptics.lightImpact()
        if willCompleteGroup {
            haptics.success()
        }
    }

    private func markGroupPaid(_ groupID: UUID) {
        let groupSeats = seats.filter { $0.id.groupID == groupID }
        let hadUnpaid = groupSeats.contains { !$0.isPaid }
        onMarkGroupPaid(groupID)
        if hadUnpaid {
            haptics.success()
        }
    }
}

private struct SeatGroup: Identifiable {
    var id: UUID { groupID }
    let groupID: UUID
    let seats: [CollectionSeat]
}

/// 画面寿命でハプティクス生成器を再利用する
private final class CollectionHaptics {
    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let notification = UINotificationFeedbackGenerator()

    func lightImpact() {
        impact.prepare()
        impact.impactOccurred()
    }

    func success() {
        notification.prepare()
        notification.notificationOccurred(.success)
    }
}

/// 席 1 行。チェック・ラベル・1 人あたり金額
private struct CollectionSeatRow: View {
    let seat: CollectionSeat
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: seat.isPaid ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(seat.isPaid ? Color.accentColor : Color.secondary)
                    .imageScale(.large)
                seatLabel
                Spacer()
                Text("result.per_person \(YenFormatting.grouped(seat.amountPerPerson))")
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(seat.isPaid ? .isSelected : [])
    }

    @ViewBuilder
    private var seatLabel: some View {
        if let displayNumber = seat.displayNumber {
            Text("collection.seat_label \(seat.groupName) \(displayNumber)")
        } else {
            Text(seat.groupName)
        }
    }
}

/// 未払い再シェア。メイン sticky の accent 全幅にはしない
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

#Preview("checks") {
    Form {
        Section("section.collection") {
            CollectionSection(
                seats: collectionPreviewSeats(paidIndexes: [1]),
                unpaidShareText: """
                未払いのお願い
                総額  35,000円
                ----------------
                一般 1  1人 6,200円
                一般 3  1人 6,200円
                ----------------
                PayPay等で送金をお願いします
                """,
                isUnpaidShareEnabled: true,
                onToggle: { _ in },
                onMarkGroupPaid: { _ in }
            )
        }
    }
}

#Preview("all paid") {
    Form {
        Section("section.collection") {
            CollectionSection(
                seats: collectionPreviewSeats(paidIndexes: [0, 1, 2]),
                unpaidShareText: "",
                isUnpaidShareEnabled: false,
                onToggle: { _ in },
                onMarkGroupPaid: { _ in }
            )
        }
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
