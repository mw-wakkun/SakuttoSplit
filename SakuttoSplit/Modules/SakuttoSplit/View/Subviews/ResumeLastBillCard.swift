//
//  ResumeLastBillCard.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import SwiftUI

/// initial かつ lastBill があるときだけ出す 1 タップ復元。確認 Alert は出さない
struct ResumeLastBillCard: View {
    let preview: LastBillPreview
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("session.resume_card_title")
                        .font(.headline)
                    Text(formattedTotal)
                        .foregroundStyle(.secondary)
                    if preview.seatCount > 0 {
                        Text("session.resume_card_unpaid \(preview.unpaidCount) \(preview.seatCount)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("session.restore")
    }

    private var formattedTotal: String {
        "\(YenFormatting.grouped(fromDigitText: preview.totalAmountText))\(String(localized: "unit.yen"))"
    }
}

#Preview("unpaid") {
    Form {
        ResumeLastBillCard(
            preview: LastBillPreview(totalAmountText: "35000", unpaidCount: 3, seatCount: 5),
            onTap: {}
        )
    }
}

#Preview("amount only") {
    Form {
        ResumeLastBillCard(
            preview: LastBillPreview(totalAmountText: "12000", unpaidCount: 0, seatCount: 0),
            onTap: {}
        )
    }
}
