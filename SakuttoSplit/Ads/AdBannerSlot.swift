//
//  AdBannerSlot.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import CoreGraphics

/// バナースロットの高さ・ロード有無。資格の `isAdFree` と View のフォーカスを合成する
enum AdBannerSlot {
    static let expandedHeight: CGFloat = 50

    /// キーボード中・広告オフ中は畳む。SDK 未 ready かつ確認中は 50pt のプレースホルダ
    static func height(isFocused: Bool, isAdFree: Bool) -> CGFloat {
        isCollapsed(isFocused: isFocused, isAdFree: isAdFree) ? 0 : expandedHeight
    }

    static func isCollapsed(isFocused: Bool, isAdFree: Bool) -> Bool {
        isFocused || isAdFree
    }

    /// 実際に SDK バナーを載せる条件。非表示中は load しない
    static func showsLoadedBanner(
        isAdsSDKReady: Bool,
        isFocused: Bool,
        isAdFree: Bool
    ) -> Bool {
        isAdsSDKReady && !isFocused && !isAdFree
    }
}
