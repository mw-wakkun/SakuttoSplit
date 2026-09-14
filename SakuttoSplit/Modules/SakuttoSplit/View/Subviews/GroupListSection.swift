//
//  GroupListSection.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

struct GroupListSection: View {
    let groups: [AttendeeGroupDraft]
    var nameBinding: (UUID) -> Binding<String>
    var countBinding: (UUID) -> Binding<String>
    var modeBinding: (UUID) -> Binding<PaymentMode>
    var fixedAmountBinding: (UUID) -> Binding<String>
    var ratioBinding: (UUID) -> Binding<String>
    var focusedField: FocusState<SakuttoSplitFocus?>.Binding
    var onAdd: () -> Void
    var onRemove: (UUID) -> Void

    var body: some View {
        ForEach(groups) { group in
            GroupRowView(
                groupID: group.id,
                name: nameBinding(group.id),
                countText: countBinding(group.id),
                mode: modeBinding(group.id),
                fixedAmountText: fixedAmountBinding(group.id),
                ratioText: ratioBinding(group.id),
                focusedField: focusedField,
                onRemove: { onRemove(group.id) }
            )
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
                nameBinding: binding(\.name),
                countBinding: binding(\.countText),
                modeBinding: binding(\.mode),
                fixedAmountBinding: binding(\.fixedAmountText),
                ratioBinding: binding(\.ratioText),
                focusedField: $focusedField,
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

    private func binding<Value>(_ keyPath: WritableKeyPath<AttendeeGroupDraft, Value>) -> (UUID) -> Binding<Value> {
        { id in
            Binding(
                get: {
                    groups.first(where: { $0.id == id })?[keyPath: keyPath]
                        ?? AttendeeGroupDraft(name: "", countText: "1")[keyPath: keyPath]
                },
                set: { newValue in
                    guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
                    groups[index][keyPath: keyPath] = newValue
                }
            )
        }
    }
}
