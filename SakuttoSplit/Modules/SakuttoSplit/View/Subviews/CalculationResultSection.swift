//
//  CalculationResultSection.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// 計算結果の値だけを受ける。回収と精算は親 Form の兄弟として置く
struct CalculationResultSection: View {
    let results: [GroupCalculationResult]
    let difference: Int
    let validationIssue: SakuttoSplitValidationIssue?

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
    }
}

/// グループ単位の計算結果行。金額は表示用 Formatter
struct ResultRow: View, Equatable {
    let result: GroupCalculationResult

    var body: some View {
        HStack {
            Text(result.name)
            Spacer()
            VStack(alignment: .trailing) {
                Text("result.per_person \(YenFormatting.grouped(result.amountPerPerson))").bold()
                Text("result.group_total \(YenFormatting.grouped(result.total))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        Section("section.results") {
            CalculationResultSection(
                results: [
                    GroupCalculationResult(groupID: UUID(), name: "部長", amountPerPerson: 10000, total: 10000),
                    GroupCalculationResult(groupID: UUID(), name: "一般", amountPerPerson: 6200, total: 24800)
                ],
                difference: -200,
                validationIssue: nil
            )
        }
    }
}

#Preview("empty total") {
    Form {
        Section("section.results") {
            CalculationResultSection(
                results: [],
                difference: 0,
                validationIssue: .emptyTotalAmount
            )
        }
    }
}
