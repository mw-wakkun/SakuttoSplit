//
//  SakuttoSplitApp.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI
import GoogleMobileAds

/// アプリのエントリポイント。Presenter と AdsController を `@StateObject` で所有する
@main
struct SakuttoSplitApp: App {
    @StateObject private var presenter: SakuttoSplitPresenter
    @StateObject private var adsController: AdsController
    @State private var bannerAdUnitID = ""
    @State private var isAdsSDKReady = false

    init() {
        let module = SakuttoSplitRouter.assembleModule()
        _presenter = StateObject(wrappedValue: module.presenter)
        _adsController = StateObject(wrappedValue: module.adsController)
    }

    var body: some Scene {
        WindowGroup {
            SakuttoSplitView(
                presenter: presenter,
                adsController: adsController,
                bannerAdUnitID: bannerAdUnitID,
                isAdsSDKReady: isAdsSDKReady
            )
            .task {
                await MobileAds.shared.start()
                await AdConfiguration.prepare()
                bannerAdUnitID = await AdConfiguration.resolvedBannerAdUnitID()
                isAdsSDKReady = true
                await adsController.startLoadingIfNeeded()
            }
        }
    }
}
