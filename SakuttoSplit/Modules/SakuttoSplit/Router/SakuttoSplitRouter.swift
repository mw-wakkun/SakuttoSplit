//
//  SakuttoSplitRouter.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// 組み立て結果。Presenter の所有権は呼び出し側（App）が持つ
struct SakuttoSplitModule {
    let presenter: SakuttoSplitPresenter
    let bannerAdUnitID: String
}

/// VIPER の各部品を初期化して繋ぎ合わせる
enum SakuttoSplitRouter {
    @MainActor
    static func assembleModule(
        adConfiguration: any AdConfigurationProviding = AdConfiguration()
    ) -> SakuttoSplitModule {
        let interactor = SakuttoSplitInteractor()
        let presenter = SakuttoSplitPresenter(interactor: interactor)
        return SakuttoSplitModule(
            presenter: presenter,
            bannerAdUnitID: adConfiguration.bannerAdUnitID
        )
    }
}
