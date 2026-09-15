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
        CollectionProgressRow(status: CollectionProgressStatus(seats: seats))

        ForEach(seatGroups) { group in
            ForEach(group.seats) { seat in
                CollectionSeatRow(seat: seat) {
                    toggleSeat(seat)
                }
            }

            if group.seats.count >= 2 {
                Button {
                    markGroupPaid(group.groupID)
                } label: {
                    Text("collection.mark_group_paid")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(group.seats.allSatisfy(\.isPaid))
                .opacity(group.seats.allSatisfy(\.isPaid) ? 0.45 : 1)
            }
        }

        UnpaidShareButton(shareText: unpaidShareText, isEnabled: isUnpaidShareEnabled)
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

/// Form の ProgressView は隣行の「全員済」をラベルに盗むため、自前のバーにする
private struct CollectionProgressRow: View {
    let status: CollectionProgressStatus

    var body: some View {
        switch status {
        case .empty:
            EmptyView()
        case .inProgress, .allPaid:
            VStack(alignment: .leading, spacing: 8) {
                statusText
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                CollectionPaidBar(paidCount: status.paidCount, seatCount: status.seatCount)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch status {
        case .empty:
            EmptyView()
        case .allPaid:
            Text("collection.all_paid")
        case .inProgress(let unpaidCount, let seatCount):
            Text("collection.progress \(unpaidCount) \(seatCount)")
        }
    }
}

private struct CollectionPaidBar: View {
    let paidCount: Int
    let seatCount: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: barWidth(in: geo.size.width))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    private func barWidth(in totalWidth: CGFloat) -> CGFloat {
        guard seatCount > 0 else { return 0 }
        return totalWidth * CGFloat(paidCount) / CGFloat(seatCount)
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
