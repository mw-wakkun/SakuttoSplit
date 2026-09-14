//
//  GroupListSection.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

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
                onRemove: { onRemove(group.id) }
            )
            .equatable()
        }

        Button(action: onAdd) {
            Label("group.add", systemImage: "plus.circle.fill")
        }
    }
}

#Preview {
    GroupListSectionPreview()
}

private struct GroupListSectionPreview: View {
    @State private var groups = [
        AttendeeGroupDraft(name: "部長", countText: "1", isFixed: true, fixedAmountText: "10000"),
        AttendeeGroupDraft(name: "一般", countText: "4", isFixed: false, ratioText: "1.0")
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
                        AttendeeGroupDraft(name: "新規グループ\(groups.count + 1)", countText: "1")
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
