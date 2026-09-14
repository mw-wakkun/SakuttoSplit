//
//  SakuttoSplitRouter.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// VIPER の各部品を初期化して繋ぎ合わせる
@MainActor
final class SakuttoSplitRouter: SakuttoSplitRouterProtocol {

    static func assembleModule() -> SakuttoSplitView {
        let interactor = SakuttoSplitInteractor()
        let presenter = SakuttoSplitPresenter(interactor: interactor)
        let adConfiguration = AdConfiguration()
        return SakuttoSplitView(
            presenter: presenter,
            bannerAdUnitID: adConfiguration.bannerAdUnitID
        )
    }
}
