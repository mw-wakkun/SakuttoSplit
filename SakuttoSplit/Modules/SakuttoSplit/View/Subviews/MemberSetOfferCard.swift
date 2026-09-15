//
//  MemberSetOfferCard.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/15.
//

import SwiftUI

/// セット 0 件の初回メインシェア後だけ出す保存カード。Alert にはしない
struct MemberSetOfferCard: View {
    var onSave: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("set.offer_title")
                        .font(.subheadline.weight(.semibold))
                    Text("set.offer_message")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("set.offer_dismiss")
            }
            Button("set.offer_save", action: onSave)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    Form {
        Section("section.collection") {
            MemberSetOfferCard(onSave: {}, onDismiss: {})
        }
    }
}
