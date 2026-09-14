//
//  SakuttoSplitApp.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI
import GoogleMobileAds

/// アプリのエントリポイント。組み立て済みモジュールを安定所有する
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
