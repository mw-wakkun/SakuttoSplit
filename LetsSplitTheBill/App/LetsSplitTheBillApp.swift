//
//  LetsSplitTheBillApp.swift
//  LetsSplitTheBill
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

@main
struct LetsSplitTheBillApp: App {
    var body: some Scene {
        WindowGroup {
            SplitBillRouter.assembleModule()
        }
    }
}
