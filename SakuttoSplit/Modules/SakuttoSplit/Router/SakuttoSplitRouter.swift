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
    static func assembleModule() -> SakuttoSplitModule {
        assembleModule(adConfiguration: AdConfiguration())
    }

    static func assembleModule(
        adConfiguration: any AdConfigurationProviding
    ) -> SakuttoSplitModule {
        let interactor = SakuttoSplitInteractor()
        let presenter = SakuttoSplitPresenter(
            interactor: interactor,
            sessionStore: BillSessionStore(),
            reminderScheduler: UnpaidReminderScheduler()
        )
        let adsController = AdsController(
            interstitialAdUnitID: adConfiguration.interstitialAdUnitID,
            rewardedAdUnitID: adConfiguration.rewardedAdUnitID
        )
        return SakuttoSplitModule(
            presenter: presenter,
            adsController: adsController,
            bannerAdUnitID: adConfiguration.bannerAdUnitID,
            interstitialAdUnitID: adConfiguration.interstitialAdUnitID,
            rewardedAdUnitID: adConfiguration.rewardedAdUnitID
        )
    }
}
