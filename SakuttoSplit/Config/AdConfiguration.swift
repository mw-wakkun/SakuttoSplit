//
//  AdConfiguration.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import Foundation
import StoreKit

/// 広告ユニット ID。DEBUG と TestFlight は Google 公式サンプル、App Store 本番だけ本番 ID。
///
/// TestFlight も Release ビルドだが、`AppTransaction.environment` が production ではないのでサンプル ID になる。
/// 判定不能なときは本番広告を出さない。端末ハッシュ（`testDeviceIdentifiers`）には依存しない。
struct AdConfiguration: AdConfigurationProviding, Equatable {
    static let googleSampleBannerUnitID = "ca-app-pub-3940256099942544/2934735716"
    static let googleSampleInterstitialUnitID = "ca-app-pub-3940256099942544/4411468910"
    static let googleSampleRewardedUnitID = "ca-app-pub-3940256099942544/1712485313"

    /// 現行バナー本番 ID。`GADApplicationIdentifier` は変えない
    static let productionBannerAdUnitID = "ca-app-pub-9676260030977388/3738962239"
    static let productionInterstitialAdUnitID = "ca-app-pub-9676260030977388/7047443390"
    static let productionRewardedAdUnitID = "ca-app-pub-9676260030977388/1795116714"

    let bannerAdUnitID: String
    let interstitialAdUnitID: String
    let rewardedAdUnitID: String

    init(
        bannerAdUnitID: String,
        interstitialAdUnitID: String,
        rewardedAdUnitID: String
    ) {
        self.bannerAdUnitID = bannerAdUnitID
        self.interstitialAdUnitID = interstitialAdUnitID
        self.rewardedAdUnitID = rewardedAdUnitID
    }

    static let googleSample = AdConfiguration(
        bannerAdUnitID: googleSampleBannerUnitID,
        interstitialAdUnitID: googleSampleInterstitialUnitID,
        rewardedAdUnitID: googleSampleRewardedUnitID
    )

    static let production = AdConfiguration(
        bannerAdUnitID: productionBannerAdUnitID,
        interstitialAdUnitID: productionInterstitialAdUnitID,
        rewardedAdUnitID: productionRewardedAdUnitID
    )

    static func resolved() async -> AdConfiguration {
        await resolvedUsesTestAdUnits() ? googleSample : production
    }

    static func resolvedBannerAdUnitID() async -> String {
        await resolved().bannerAdUnitID
    }

    static func resolvedInterstitialAdUnitID() async -> String {
        await resolved().interstitialAdUnitID
    }

    static func resolvedRewardedAdUnitID() async -> String {
        await resolved().rewardedAdUnitID
    }

    /// DEBUG、TestFlight、判定不能はテスト広告。App Store の production だけ false。
    static func resolvedUsesTestAdUnits() async -> Bool {
        #if DEBUG
        selectsTestAdUnits(isDebugBuild: true, distribution: .appStoreProduction)
        #else
        selectsTestAdUnits(isDebugBuild: false, distribution: await currentDistribution())
        #endif
    }

    /// 起動時に environment を先読みする。広告 load 側でも待つので、呼ばれなくても安全。
    static func prepare() async {
        _ = await resolvedUsesTestAdUnits()
    }

    /// App Store 本番以外はテスト広告にする。判定不能なら本番広告を出さない。
    static func selectsTestAdUnits(isDebugBuild: Bool, distribution: AdsDistribution) -> Bool {
        if isDebugBuild {
            return true
        }
        return distribution != .appStoreProduction
    }

    static func distribution(from environment: AppStore.Environment?) -> AdsDistribution {
        environment == .production ? .appStoreProduction : .testFlightOrUnknown
    }

    /// StoreKit の environment。production 以外（TestFlight / Xcode / 不明）はテスト広告。
    enum AdsDistribution: Equatable {
        case appStoreProduction
        case testFlightOrUnknown
    }

    #if !DEBUG
    private static let environmentTask = Task<AppStore.Environment?, Never> {
        do {
            switch try await AppTransaction.shared {
            case .verified(let transaction), .unverified(let transaction, _):
                return transaction.environment
            }
        } catch {
            return nil
        }
    }

    private static func currentDistribution() async -> AdsDistribution {
        distribution(from: await environmentTask.value)
    }
    #endif
}
