//
//  MemberSetSheet.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import SwiftUI

/// 保存した編成の一覧。同じ Presenter の Intent に乗せる
struct MemberSetSheet: View {
    let memberSets: [MemberSet]
    var onSelect: (UUID) -> Void
    var onDelete: (UUID) -> Void
    var onClose: () -> Void

    @State private var pendingDeleteID: UUID?

    var body: some View {
        NavigationStack {
            List {
                if memberSets.isEmpty {
                    Text("set.empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(memberSets) { memberSet in
                        Button {
                            onSelect(memberSet.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(memberSet.name)
                                    .foregroundStyle(.primary)
                                Text(verbatim: memberSet.compositionPreview)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteID = memberSet.id
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("set.load")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.done", action: onClose)
                }
            }
            .alert("set.delete_confirm", isPresented: isDeleteConfirmPresented) {
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
}

#Preview("empty") {
    MemberSetSheet(memberSets: [], onSelect: { _ in }, onDelete: { _ in }, onClose: {})
}

#Preview("list") {
    MemberSetSheet(
        memberSets: [
            MemberSet(
                name: "いつもの飲み会",
                roundingUnit: .hundred,
                groups: [
                    AttendeeGroupDraft(name: "部長", countText: "1", mode: .fixed, fixedAmountText: "10000"),
                    AttendeeGroupDraft(name: "一般", countText: "4", mode: .ratio, ratioText: "1.0")
                ]
            )
        ],
        onSelect: { _ in },
        onDelete: { _ in },
        onClose: {}
    )
}
