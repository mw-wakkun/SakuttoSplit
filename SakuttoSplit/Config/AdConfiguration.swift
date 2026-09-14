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
        #if !DEBUG
        precondition(
            !bannerAdUnitID.isEmpty && !interstitialAdUnitID.isEmpty && !rewardedAdUnitID.isEmpty,
            "Release では banner / interstitial / rewarded の本番ユニット ID がすべて必要。AdMob コンソールで発行して AdConfiguration に入れる"
        )
        #endif
        self.bannerAdUnitID = bannerAdUnitID
        self.interstitialAdUnitID = interstitialAdUnitID
        self.rewardedAdUnitID = rewardedAdUnitID
    }

    static var defaultBannerAdUnitID: String {
        #if DEBUG
        GoogleTestAdUnitIDs.banner
        #else
        productionBannerAdUnitID
        #endif
    }

    static var defaultInterstitialAdUnitID: String {
        #if DEBUG
        GoogleTestAdUnitIDs.interstitial
        #else
        productionInterstitialAdUnitID
        #endif
    }

    static var defaultRewardedAdUnitID: String {
        #if DEBUG
        GoogleTestAdUnitIDs.rewarded
        #else
        productionRewardedAdUnitID
        #endif
    }

    /// 現行バナー本番 ID。`GADApplicationIdentifier` は変えない
    static let productionBannerAdUnitID = "ca-app-pub-9676260030977388/3738962239"
    static let productionInterstitialAdUnitID = "ca-app-pub-9676260030977388/7047443390"
    static let productionRewardedAdUnitID = "ca-app-pub-9676260030977388/1795116714"
}

private enum GoogleTestAdUnitIDs {
    static let banner = "ca-app-pub-3940256099942544/2934735716"
    static let interstitial = "ca-app-pub-3940256099942544/4411468910"
    static let rewarded = "ca-app-pub-3940256099942544/1712485313"
}
