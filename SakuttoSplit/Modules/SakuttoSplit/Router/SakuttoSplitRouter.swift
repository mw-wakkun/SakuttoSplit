//
//  SakuttoSplitRouter.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// 組み立て結果。Presenter / AdsController の所有権は呼び出し側（App）が持つ
struct SakuttoSplitModule {
    let presenter: SakuttoSplitPresenter
    let adsController: AdsController
    let bannerAdUnitID: String
    let interstitialAdUnitID: String
    let rewardedAdUnitID: String
}

/// VIPER の各部品を初期化して繋ぎ合わせる
enum SakuttoSplitRouter {
    /// 本番組み立て。ユニット ID は App / AdsController が配信判定のあと解決する
    static func assembleModule() -> SakuttoSplitModule {
        assemble(adsController: AdsController(), bannerAdUnitID: "", interstitialAdUnitID: "", rewardedAdUnitID: "")
    }

    static func assembleModule(
        adConfiguration: any AdConfigurationProviding
    ) -> SakuttoSplitModule {
        assemble(
            adsController: AdsController(
                interstitialAdUnitID: adConfiguration.interstitialAdUnitID,
                rewardedAdUnitID: adConfiguration.rewardedAdUnitID
            ),
            bannerAdUnitID: adConfiguration.bannerAdUnitID,
            interstitialAdUnitID: adConfiguration.interstitialAdUnitID,
            rewardedAdUnitID: adConfiguration.rewardedAdUnitID
        )
    }

    private static func assemble(
        adsController: AdsController,
        bannerAdUnitID: String,
        interstitialAdUnitID: String,
        rewardedAdUnitID: String
    ) -> SakuttoSplitModule {
        let interactor = SakuttoSplitInteractor()
        let presenter = SakuttoSplitPresenter(
            interactor: interactor,
            sessionStore: BillSessionStore(),
            reminderScheduler: UnpaidReminderScheduler()
        )
        return SakuttoSplitModule(
            presenter: presenter,
            adsController: adsController,
            bannerAdUnitID: bannerAdUnitID,
            interstitialAdUnitID: interstitialAdUnitID,
            rewardedAdUnitID: rewardedAdUnitID
        )
    }
}
