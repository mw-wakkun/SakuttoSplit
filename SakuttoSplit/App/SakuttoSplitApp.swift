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
    @State private var splitView = SakuttoSplitRouter.assembleModule()

    var body: some Scene {
        WindowGroup {
            splitView
                .task {
                    await MobileAds.shared.start()
                }
        }
    }
}
