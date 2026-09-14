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
- **Router**: `SakuttoSplitModule`（Presenter と bannerAdUnitID）を返す。`AnyView` は使わない。
- **App**: `assembleModule()` は `init` のみ。Presenter を `@StateObject` で所有する。
- **Config**: 広告ユニット ID（`AdConfiguration`）と入力上限（`InputLimits`）。人数は 1...999（空欄・0・非数字は UI で `"1"` に正規化）。

プロトコルは `SakuttoSplitContract.swift` に集約し、Presenter / Interactor はプロトコル経由で差し替えできるようにしています。

## 品質担保
`SakuttoSplitTests` で Interactor / Presenter / Router / Entity 変換 / 入力正規化を `XCTest` しています。テストファイル名とクラス名は対応させています。

- Interactor: 均等割り、固定額と割合の混合、端数単位、空入力、固定額超過、同名グループなど
- Presenter: 入力正規化、1 Intent = 1 計算、シェア文、バリデーションとシェア可否
- 計算結果の identity はグループ名ではなく `groupID`

## スクリーンショット
| 入力画面 | 計算結果とシェア |
| --- | --- |
| <img width="1206" height="2622" alt="output" src="https://github.com/user-attachments/assets/c3da3e5a-9ef9-418c-8f72-0ce275ade20c" /> | <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-05-05 at 22 13 20" src="https://github.com/user-attachments/assets/4cd23f1f-0df8-421f-9661-64961945e8df" />

## 開発者
- mw-wakkun
