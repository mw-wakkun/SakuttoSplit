//
//  ShareResultButton.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// Form 外のメインシェア。Accent 全幅。入力エラー時は disabled
struct ShareResultButton: View, Equatable {
    let shareText: String
    let isEnabled: Bool

    var body: some View {
        ShareLink(item: shareText) {
            Label("share.button", systemImage: "square.and.arrow.up")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .background(Color.accentColor)
    }
}

#Preview("sticky enabled") {
    VStack(spacing: 0) {
        Spacer()
        ShareResultButton(shareText: "本日のお会計", isEnabled: true)
    }
}

#Preview("sticky disabled") {
    VStack(spacing: 0) {
        Spacer()
        ShareResultButton(shareText: "本日のお会計", isEnabled: false)
    }
}
