//
//  AdConfiguration.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation

/// DEBUG / Release の広告ユニット ID を組み立て側へ渡す
struct AdConfiguration: AdConfigurationProviding {
    let bannerAdUnitID: String

    init(bannerAdUnitID: String = Self.defaultBannerAdUnitID) {
        self.bannerAdUnitID = bannerAdUnitID
    }

    static var defaultBannerAdUnitID: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/2934735716"
        #else
        "ca-app-pub-9676260030977388/3738962239"
        #endif
    }
}
