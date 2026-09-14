//
//  CalculationResultSection.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// 計算結果の値だけを受ける。メインシェアは親の sticky に置く
struct CalculationResultSection: View {
    let results: [GroupCalculationResult]
    let difference: Int
    let validationIssue: SakuttoSplitValidationIssue?
    var collectionSeats: [CollectionSeat] = []
    var unpaidShareText: String = ""
    var isUnpaidShareEnabled: Bool = false
    var onToggleCollectionSeat: (CollectionSeatID) -> Void = { _ in }
    var onSettleComplete: () -> Void

    var body: some View {
        ForEach(results) { result in
            ResultRow(result: result)
                .equatable()
        }

        DifferenceRow(difference: difference)
            .equatable()

        if let validationIssue {
            Text(validationIssue.messageKey)
                .font(.footnote)
                .foregroundStyle(.red)
        }

        if !collectionSeats.isEmpty {
            CollectionSection(
                seats: collectionSeats,
                unpaidShareText: unpaidShareText,
                isUnpaidShareEnabled: isUnpaidShareEnabled,
                onToggle: onToggleCollectionSeat
            )
        }

        SettleCompleteButton(validationIssue: validationIssue, action: onSettleComplete)
    }
}

/// グループ単位の計算結果行
struct ResultRow: View, Equatable {
    let result: GroupCalculationResult

    var body: some View {
        HStack {
            Text(result.name)
            Spacer()
            VStack(alignment: .trailing) {
                Text("result.per_person \(result.amountPerPerson)").bold()
                Text("result.group_total \(result.total)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private extension SakuttoSplitValidationIssue {
    var messageKey: LocalizedStringKey {
        switch self {
        case .emptyTotalAmount:
            "validation.empty_total"
        case .noGroups:
            "validation.no_groups"
        case .fixedAmountExceedsTotal:
            "validation.fixed_exceeds_total"
        }
    }
}

#Preview("results") {
    Form {
        CalculationResultSection(
            results: [
                GroupCalculationResult(groupID: UUID(), name: "部長", amountPerPerson: 10000, total: 10000),
                GroupCalculationResult(groupID: UUID(), name: "一般", amountPerPerson: 6200, total: 24800)
            ],
            difference: -200,
            validationIssue: nil,
            collectionSeats: {
                let groupID = UUID()
                return (0..<4).map { index in
                    CollectionSeat(
                        id: CollectionSeatID(groupID: groupID, index: index),
                        groupName: "一般",
                        displayNumber: index + 1,
                        amountPerPerson: 6200,
                        isPaid: index == 1
                    )
                }
            }(),
            unpaidShareText: "🍻 未払いのお願い 🍻",
            isUnpaidShareEnabled: true,
            onSettleComplete: {}
        )
    }
}

#Preview("empty total") {
    Form {
        CalculationResultSection(
            results: [],
            difference: 0,
            validationIssue: .emptyTotalAmount,
            onSettleComplete: {}
        )
    }
}

#Preview("hidden") {
    Form {
        CalculationResultSection(
            results: [],
            difference: 0,
            validationIssue: .emptyTotalAmount,
            collectionSeats: [],
            onSettleComplete: {}
        )
    }
}
