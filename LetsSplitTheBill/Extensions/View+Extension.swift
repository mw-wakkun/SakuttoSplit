//
//  View+Extension.swift
//  LetsSplitTheBill
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

extension View {
    /// キーボードを閉じるメソッド
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
