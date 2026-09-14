//
//  AdConfiguration.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// DEBUG / Release の広告ユニット ID を組み立て側へ渡す
struct AdConfiguration: AdConfigurationProviding {
    let bannerAdUnitID: String
    let interstitialAdUnitID: String
    let rewardedAdUnitID: String

    init(
        bannerAdUnitID: String = Self.defaultBannerAdUnitID,
        interstitialAdUnitID: String = Self.defaultInterstitialAdUnitID,
        rewardedAdUnitID: String = Self.defaultRewardedAdUnitID
    ) {
        self.bannerAdUnitID = bannerAdUnitID
        self.interstitialAdUnitID = interstitialAdUnitID
        self.rewardedAdUnitID = rewardedAdUnitID
    }

    static var defaultBannerAdUnitID: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/2934735716"
        #else
        "ca-app-pub-9676260030977388/3738962239"
        #endif
    }

    static var defaultInterstitialAdUnitID: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/4411468910"
        #else
        // 本番 ID はフェーズ 5 で AdMob コンソール発行後に入れる
        ""
        #endif
    }

    static var defaultRewardedAdUnitID: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/1712485313"
        #else
        // 本番 ID はフェーズ 5 で AdMob コンソール発行後に入れる
        ""
        #endif
    }
}
