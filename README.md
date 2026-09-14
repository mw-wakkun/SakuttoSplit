# サクッと割り勘 (SakuttoSplit)
飲み会やイベントの精算を「サクッと」終わらせるための、iOS向け高機能割り勘計算アプリです。
単なる均等割りだけでなく、「上司は多めに」「遅れてきた人は固定額で」といった複雑な支払いパターンを、シンプルな操作で解決します。

## 特徴
- **ハイブリッド計算**: 固定額支払い（例：部長は1万円）と、割合支払い（例：一般社員は等倍）を組み合わせて同時に計算可能。
- **柔軟な端数処理**: 1円〜1000円単位での切り捨て処理に対応し、現場で扱いやすい集金額を算出。
- **リアルタイム更新**: 入力内容を即座に計算結果に反映。
- **結果シェア機能**: 計算結果を整形し、LINEやメッセージアプリへ素早く共有。

## 技術スタック
- **Language**: Swift 6.0
- **UI Framework**: SwiftUI
- **Architecture**: **VIPER**（View / Interactor / Presenter / Entity / Router）。SwiftUI 向けに Intent / ViewState 方式
- **Unit Testing**: XCTest

## アーキテクチャ
View は描画と Intent の転送だけを行い、判断・正規化・計算起動は Presenter、割り勘計算は Interactor、生成物は Entity、組み立ては Router が担います。

- **View**: `SakuttoSplitView` は `SakuttoSplitPresenterProtocol` に対してジェネリック。観察は `@ObservedObject` のみ。サブビューは Presenter 全体を受け取らず、コントロールが要求する Binding アダプタと、リスト行の Intent クロージャを使い分ける。
- **Presenter**: `@MainActor`。`viewState` を 1 つの `@Published` で公開し、入力 Intent のたびに計算を 1 回行う。シェア文面は `viewState.shareText`、入力バリデーションもここ。
- **Interactor**: `SakuttoSplitInteractorProtocol` に適合。`BillCalculationInput` を受け、`BillCalculationOutput` を返す同期の純関数。
- **Entity**: `AttendeeGroup`（ドメイン）、`AttendeeGroupDraft`（TextField 用）、`PaymentMode`、`RoundingUnit`、計算の入出力。
- **Router**: `SakuttoSplitModule`（Presenter、`AdsController`、banner / interstitial / rewarded の 3 ID）を返す。`AnyView` は使わない。
- **App**: `assembleModule()` は `init` のみ。Presenter と `AdsController` を `@StateObject` で所有する。SDK `start` 完了後に `startLoadingIfNeeded`。
- **Ads**: 資格判定は `AdEligibility`、広告オフ期限は `AdFreeStore`（UserDefaults）。`GoogleMobileAds` の import は App / `AdBannerView` / `AdsController` のみ。計算 Presenter は広告 SDK を知らない。
- **Config**: 広告ユニット ID（`AdConfiguration`。DEBUG は Google テスト ID、Release は本番 3 ID）と入力上限（`InputLimits`）。人数は 1...999（空欄・0・非数字は UI で `"1"` に正規化）。

プロトコルは `SakuttoSplitContract.swift` に集約し、Presenter / Interactor はプロトコル経由で差し替えできるようにしています。

## 品質担保
`SakuttoSplitTests` で Interactor / Presenter / Router / Entity 変換 / 入力正規化を `XCTest` しています。テストファイル名とクラス名は対応させています。

- Interactor: 均等割り、固定額と割合の混合、端数単位、空入力、固定額超過、同名グループなど
- Presenter: 入力正規化、1 Intent = 1 計算、シェア文、バリデーションとシェア可否
- 計算結果の identity はグループ名ではなく `groupID`
- 広告: 資格判定・精算リセット・広告オフ期限。SDK 本体は叩かない

## 広告
割り勘の「サクッと」を維持するため、広告は入力の邪魔にならない位置と、ユーザーが自分で区切った直後にだけ出す。

- **バナー**: 画面最下部、Form の外。キーボード表示中（いずれかの入力がフォーカス中）は高さ 0 で畳み、確認中だけ出す。広告オフ中も畳む。SDK 未 ready かつキーボードなしのときは高さ 50 のプレースホルダ。入力のたびに再 load しない。
- **インタースティシャル**: 「精算完了（次の会計へ）」が成功した直後だけ。起動・シェア・入力・バックグラウンド復帰では出さない。起動から 15 秒未満、未 load、このプロセスで既に 1 回出した、広告オフ中は出さず、リセットだけ行う。待ちダイアログは出さない。
- **リワード**: 右上のボタンを押したときだけ動画を再生する。最後まで見ると 24 時間、バナーとインタースティシャルの両方を止める。途中閉じでは付与しない。未 load なら「広告を読み込めませんでした」と短く伝え、落とさない。
- **出さないもの**: App Open、起動時全画面、シェア前後の全画面、ATT ダイアログ（v2.0.0 は非パーソナライズ）。
- **ID**: DEBUG は Google 公式テスト ID。Release は AdMob 本番 3 ID（バナー / インタースティシャル / リワード）。`GADApplicationIdentifier` は変えない。

## スクリーンショット
| 入力画面 | 計算結果とシェア |
| --- | --- |
| <img width="1206" height="2622" alt="output" src="https://github.com/user-attachments/assets/c3da3e5a-9ef9-418c-8f72-0ce275ade20c" /> | <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-05-05 at 22 13 20" src="https://github.com/user-attachments/assets/4cd23f1f-0df8-421f-9661-64961945e8df" />

## 開発者
- mw-wakkun
