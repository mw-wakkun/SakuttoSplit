//
//  CalculationResultSection.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

struct CalculationResultSection: View {
    let results: [GroupCalculationResult]
    let difference: Int
    let shareText: String

    var body: some View {
        ForEach(results) { result in
            HStack {
                Text(result.name)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("result.per_person \(result.amountPerPerson)").bold()
                    Text("result.group_total \(result.total)").font(.caption).foregroundColor(.secondary)
                }
            }
        }

        DifferenceRow(difference: difference)
        ShareResultButton(shareText: shareText)
    }
}

#Preview {
    Form {
        CalculationResultSection(
            results: [
                GroupCalculationResult(groupID: UUID(), name: "部長", amountPerPerson: 10000, total: 10000),
                GroupCalculationResult(groupID: UUID(), name: "一般", amountPerPerson: 6200, total: 24800)
            ],
            difference: -200,
            shareText: "🍻 本日のお会計 🍻"
        )
    }
}
