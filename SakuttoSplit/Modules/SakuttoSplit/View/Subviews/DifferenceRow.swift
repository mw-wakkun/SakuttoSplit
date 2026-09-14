//
//  DifferenceRow.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// 過不足金の 1 行
struct DifferenceRow: View, Equatable {
    let difference: Int

    var body: some View {
        HStack {
            Text(difference >= 0 ? "difference.surplus" : "difference.shortage")
            Spacer()
            Text("difference.amount \(YenFormatting.grouped(abs(difference)))")
                .bold()
                .foregroundStyle(difference >= 0 ? .green : .red)
        }
    }
}

#Preview("surplus") {
    Form {
        DifferenceRow(difference: 200)
    }
}

#Preview("shortage") {
    Form {
        DifferenceRow(difference: -200)
    }
}
