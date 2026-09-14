//
//  SettleCompleteButton.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import SwiftUI

/// 精算完了行。シェアより目立たせない二次 CTA。緑背景は使わない
struct SettleCompleteButton: View {
    let isEnabled: Bool
    let action: () -> Void

    init(validationIssue: SakuttoSplitValidationIssue?, action: @escaping () -> Void) {
        self.isEnabled = validationIssue == nil
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text("settle.complete")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

#Preview("enabled") {
    Form {
        SettleCompleteButton(validationIssue: nil, action: {})
    }
}

#Preview("disabled") {
    Form {
        SettleCompleteButton(validationIssue: .emptyTotalAmount, action: {})
    }
}
