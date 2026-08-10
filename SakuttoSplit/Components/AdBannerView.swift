//
//  AdBannerView.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/08/10.
//

import SwiftUI
import GoogleMobileAds

struct AdBannerView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView { // GADBannerView -> BannerView
        // GADAdSizeBanner -> AdSizeBanner
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            banner.rootViewController = rootViewController
        }
        
        banner.load(Request()) // GADRequest() -> Request()
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
