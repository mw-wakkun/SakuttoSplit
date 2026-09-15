//
//  BillHistorySheet.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import SwiftUI

/// 直近会計の一覧。MemberSetSheet と同型。Navigation の画面スタックは増やさない
struct BillHistorySheet: View {
    let entries: [BillHistoryEntry]
    var onContinue: (UUID) -> Void
    var onStartComposition: (UUID) -> Void
    var onDelete: (UUID) -> Void
    var onClose: () -> Void

    @State private var pendingDeleteID: UUID?

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    Text("history.empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entries) { entry in
                        Button {
                            onContinue(entry.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: formattedTotal(entry.snapshot.totalAmountText))
                                    .foregroundStyle(.primary)
                                Text(verbatim: secondaryLine(entry))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if entry.unpaidCount >= 1 {
                                    Text("history.unpaid \(entry.unpaidCount)")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button("history.start_composition") {
                                onStartComposition(entry.id)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteID = entry.id
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("history.open")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.done", action: onClose)
                }
            }
            .alert("history.delete_confirm", isPresented: isDeleteConfirmPresented) {
                Button(role: .destructive) {
                    if let id = pendingDeleteID {
                        onDelete(id)
                    }
                    pendingDeleteID = nil
                }
                Button(role: .cancel) {
                    pendingDeleteID = nil
                }
            }
        }
    }

    private var isDeleteConfirmPresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteID != nil },
            set: { if !$0 { pendingDeleteID = nil } }
        )
    }

    private func formattedTotal(_ totalAmountText: String) -> String {
        "\(YenFormatting.grouped(fromDigitText: totalAmountText))\(String(localized: "unit.yen"))"
    }

    private func secondaryLine(_ entry: BillHistoryEntry) -> String {
        let dateText = entry.savedAt.formatted(
            Date.FormatStyle()
                .month(.defaultDigits)
                .day()
                .locale(Locale(identifier: "ja_JP"))
        )
        return "\(dateText) \(entry.compositionPreview)"
    }
}

#Preview("empty") {
    BillHistorySheet(
        entries: [],
        onContinue: { _ in },
        onStartComposition: { _ in },
        onDelete: { _ in },
        onClose: {}
    )
}

#Preview("list") {
    BillHistorySheet(
        entries: [
            BillHistoryEntry(
                savedAt: Date(timeIntervalSince1970: 1_779_000_000),
                snapshot: BillSnapshot(
                    totalAmountText: "35000",
                    roundingUnit: .hundred,
                    groups: [
                        AttendeeGroupDraft(name: "部長", countText: "1", mode: .fixed, fixedAmountText: "10000"),
                        AttendeeGroupDraft(name: "一般", countText: "4", mode: .ratio, ratioText: "1.0")
                    ],
                    paidSeatKeys: []
                )
            )
        ],
        onContinue: { _ in },
        onStartComposition: { _ in },
        onDelete: { _ in },
        onClose: {}
    )
}
