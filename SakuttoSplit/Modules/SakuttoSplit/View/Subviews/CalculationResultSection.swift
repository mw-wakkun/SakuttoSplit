//
//  CalculationResultSection.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// 計算結果の値だけを受ける。入力中の TextField とは切り離す
struct CalculationResultSection: View {
    let results: [GroupCalculationResult]
    let difference: Int
    let shareText: String
    let validationIssue: SakuttoSplitValidationIssue?
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

        // ShareLink + listRowBackground は EquatableView に包むと行背景が落ち、白文字が見えなくなる
        ShareResultButton(shareText: shareText, isEnabled: validationIssue == nil)

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
            shareText: "🍻 本日のお会計 🍻",
            validationIssue: nil,
            onSettleComplete: {}
        )
    }
}

#Preview("empty total") {
    Form {
        CalculationResultSection(
            results: [],
            difference: 0,
            shareText: "",
            validationIssue: .emptyTotalAmount,
            onSettleComplete: {}
        )
    }
}
