//
//  GroupListSection.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// 参加者グループ一覧と追加ボタン。削除は swipe。保存/読込は置かない
struct GroupListSection: View {
    let groups: [AttendeeGroupDraft]
    var focusedField: FocusState<SakuttoSplitFocus?>.Binding
    var onNameChange: (UUID, String) -> Void
    var onCountChange: (UUID, String) -> Void
    var onModeChange: (UUID, PaymentMode) -> Void
    var onFixedAmountChange: (UUID, String) -> Void
    var onRatioChange: (UUID, String) -> Void
    var onAdd: () -> Void
    var onRemove: (UUID) -> Void
    var onPaymentExpandedChange: (UUID, Bool) -> Void = { _, _ in }

    var body: some View {
        ForEach(groups) { group in
            GroupRowView(
                group: group,
                focusedField: focusedField,
                onNameChange: { onNameChange(group.id, $0) },
                onCountChange: { onCountChange(group.id, $0) },
                onModeChange: { onModeChange(group.id, $0) },
                onFixedAmountChange: { onFixedAmountChange(group.id, $0) },
                onRatioChange: { onRatioChange(group.id, $0) },
                onPaymentExpandedChange: { onPaymentExpandedChange(group.id, $0) }
            )
            .equatable()
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    onRemove(group.id)
                }
            }
        }

        Button(action: onAdd) {
            Label("group.add", systemImage: "plus.circle.fill")
        }
        .disabled(groups.count >= InputLimits.groupMaxCount)
    }
}

#Preview {
    GroupListSectionPreview()
}

private struct GroupListSectionPreview: View {
    @State private var groups = [
        AttendeeGroupDraft(name: "部長", countText: "1", mode: .fixed, fixedAmountText: "10000"),
        AttendeeGroupDraft(name: "一般", countText: "4", mode: .ratio, ratioText: "1.0")
    ]
    @FocusState private var focusedField: SakuttoSplitFocus?

    var body: some View {
        Form {
            GroupListSection(
                groups: groups,
                focusedField: $focusedField,
                onNameChange: { update($0, \.name, $1) },
                onCountChange: { update($0, \.countText, $1) },
                onModeChange: { update($0, \.mode, $1) },
                onFixedAmountChange: { update($0, \.fixedAmountText, $1) },
                onRatioChange: { update($0, \.ratioText, $1) },
                onAdd: {
                    groups.append(
                        AttendeeGroupDraft(
                            name: String(localized: "group.new_name \(groups.count + 1)"),
                            countText: "1"
                        )
                    )
                },
                onRemove: { id in
                    groups.removeAll { $0.id == id }
                }
            )
        }
    }

    private func update<Value>(
        _ id: UUID,
        _ keyPath: WritableKeyPath<AttendeeGroupDraft, Value>,
        _ value: Value
    ) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[index][keyPath: keyPath] = value
    }
}
