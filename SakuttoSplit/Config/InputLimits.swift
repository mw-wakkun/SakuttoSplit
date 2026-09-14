//
//  InputLimits.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// 入力欄の桁数・人数範囲など、Presenter が正規化に使う上限
enum InputLimits {
    static let totalAmountMaxDigits = 8
    static let groupCountRange = 1...999

    static func sanitizedTotalAmountText(_ text: String) -> String {
        sanitizedDigitText(text, maxDigits: totalAmountMaxDigits)
    }

    static func sanitizedFixedAmountText(_ text: String) -> String {
        sanitizedDigitText(text, maxDigits: totalAmountMaxDigits)
    }

    static func sanitizedCountText(_ text: String) -> String {
        let digits = text.filter(\.isNumber)
        guard !digits.isEmpty else {
            return String(groupCountRange.lowerBound)
        }
        guard let value = Int(digits) else {
            return String(groupCountRange.upperBound)
        }
        let clamped = min(max(value, groupCountRange.lowerBound), groupCountRange.upperBound)
        return String(clamped)
    }

    static func sanitizedRatioText(_ text: String) -> String {
        var result = ""
        var hasDot = false
        for character in text {
            if character.isNumber {
                result.append(character)
            } else if character == "." && !hasDot {
                result.append(character)
                hasDot = true
            }
        }
        return result
    }

    static func sanitizedDigitText(_ text: String, maxDigits: Int) -> String {
        String(text.filter(\.isNumber).prefix(maxDigits))
    }
}
