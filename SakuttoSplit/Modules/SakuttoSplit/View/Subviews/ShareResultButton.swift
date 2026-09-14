//
//  ShareResultButton.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// 計算結果のシェア行。入力エラー時は disabled
struct ShareResultButton: View, Equatable {
    let shareText: String
    let isEnabled: Bool

    var body: some View {
        ShareLink(item: shareText) {
            Label("share.button", systemImage: "message.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .listRowBackground(Color.green)
    }
}

#Preview("enabled") {
    Form {
        ShareResultButton(shareText: "🍻 本日のお会計 🍻", isEnabled: true)
    }
}

#Preview("disabled") {
    Form {
        ShareResultButton(shareText: "🍻 本日のお会計 🍻", isEnabled: false)
    }
}
