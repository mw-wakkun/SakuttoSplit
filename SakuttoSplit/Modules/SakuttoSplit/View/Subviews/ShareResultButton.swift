//
//  ShareResultButton.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

struct ShareResultButton: View {
    let shareText: String

    var body: some View {
        ShareLink(item: shareText) {
            Label("share.button", systemImage: "message.fill")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .listRowBackground(Color.green)
    }
}

#Preview {
    Form {
        ShareResultButton(shareText: "🍻 本日のお会計 🍻")
    }
}
