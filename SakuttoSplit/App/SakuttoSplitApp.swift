//
//  SakuttoSplitApp.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI
import GoogleMobileAds

/// アプリのエントリポイント。Presenter を `@StateObject` で所有する
@main
struct SakuttoSplitApp: App {
    @StateObject private var presenter: SakuttoSplitPresenter
    private let bannerAdUnitID: String
    @State private var isAdsSDKReady = false

    init() {
        let module = SakuttoSplitRouter.assembleModule()
        _presenter = StateObject(wrappedValue: module.presenter)
        bannerAdUnitID = module.bannerAdUnitID
    }

    var body: some Scene {
        WindowGroup {
            SakuttoSplitView(
                presenter: presenter,
                bannerAdUnitID: bannerAdUnitID,
                isAdsSDKReady: isAdsSDKReady
            )
            .task {
                await MobileAds.shared.start()
                isAdsSDKReady = true
            }
        }
    }
}
