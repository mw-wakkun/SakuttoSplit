//
//  SakuttoSplitApp.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

@main
struct SakuttoSplitApp: App {
    var body: some Scene {
        WindowGroup {
            SakuttoSplitRouter.assembleModule()
        }
    }
}
