//
//  AdBannerView.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/08/10.
//

import SwiftUI
import GoogleMobileAds

/// Form の再描画から独立させる。`adUnitID` が同じなら `makeUIView` も再ロードもしない
struct AdBannerView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> AdBannerContainerView {
        AdBannerContainerView(adUnitID: adUnitID)
    }

    func updateUIView(_ uiView: AdBannerContainerView, context: Context) {
        uiView.updateAdUnitID(adUnitID)
    }
}

extension AdBannerView: Equatable {}

/// `rootViewController` を `UIApplication` ではなく、自身が載った `window` から取る
final class AdBannerContainerView: UIView {
    private let bannerView: BannerView
    private var didLoadAd = false

    init(adUnitID: String) {
        bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        super.init(frame: .zero)
        installBanner()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        bannerView = BannerView(adSize: AdSizeBanner)
        super.init(coder: coder)
        installBanner()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        loadAdIfNeeded()
    }

    func updateAdUnitID(_ adUnitID: String) {
        guard bannerView.adUnitID != adUnitID else {
            loadAdIfNeeded()
            return
        }
        bannerView.adUnitID = adUnitID
        didLoadAd = false
        loadAdIfNeeded()
    }

    private func installBanner() {
        addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bannerView.topAnchor.constraint(equalTo: topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    /// SDK の `start` 完了後に View が載ることだけを前提にする。Container は SDK 状態を持たない
    private func loadAdIfNeeded() {
        guard !didLoadAd, let window, let rootViewController = window.rootViewController else {
            return
        }
        bannerView.rootViewController = rootViewController
        bannerView.load(Request())
        didLoadAd = true
    }
}
