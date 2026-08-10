//
//  SakuttoSplitApp.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI
import GoogleMobileAds

@main
struct SakuttoSplitApp: App {
    var body: some Scene {
        WindowGroup {
            SakuttoSplitRouter.assembleModule()
                .task {
                    await MobileAds.shared.start()
                }
        }
    }
}
