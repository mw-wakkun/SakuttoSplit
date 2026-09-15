# サクッと割り勘 (SakuttoSplit)
飲み会やイベントの精算を「サクッと」終わらせるための、iOS向け高機能割り勘計算アプリです。
単なる均等割りだけでなく、「上司は多めに」「遅れてきた人は固定額で」といった複雑な支払いパターンを、シンプルな操作で解決します。

## 特徴
- **ハイブリッド計算**: 固定額支払い（例：部長は1万円）と、割合支払い（例：一般社員は等倍）を組み合わせて同時に計算可能。
- **柔軟な端数処理**: 1円〜1000円単位での切り捨て処理に対応し、現場で扱いやすい集金額を算出。
- **リアルタイム更新**: 入力内容を即座に計算結果に反映。
- **結果シェア機能**: レシート調の文面を、画面下の sticky シェアから LINE 等へ送る。キーボード中は toolbar のシェア。

## 画面
起動はいつも初期画面（部長 1 / 一般 4、総額は空）。VoiceOver オフなら総額にフォーカスする。前回会計は自動では戻さない。

```
お会計設定 … 再開カード（初期画面かつ前回ありのときだけ） / ヒーロー総額 / 端数（ディスクロージャ）
参加者グループ … 名前と人数。支払いモードは折りたたみ。保存/読込は置かない
計算結果 … 1人あたり・過不足
回収 … 妥当な入力のときだけ。チェックと全員済
精算完了 … 確認のあとだけリセット
sticky シェア … Form の外、バナー直上。キーボード中は畳む
バナー
```

右上 Menu に編成の保存/読込、会計の履歴、そして「今日の広告をオフ」。初期画面の再開カードは 1 タップ。入力中（dirty）の復元だけ左上で、確認 Alert が出る。

## 技術スタック
- **Language**: Swift 6.0
- **UI Framework**: SwiftUI
- **Architecture**: **VIPER**（View / Interactor / Presenter / Entity / Router）。SwiftUI 向けに Intent / ViewState 方式
- **Unit Testing**: XCTest

## アーキテクチャ
View は描画と Intent の転送だけを行い、判断・正規化・計算起動は Presenter、割り勘計算は Interactor、生成物は Entity、組み立ては Router が担います。

- **View**: `SakuttoSplitView` は `SakuttoSplitPresenterProtocol` に対してジェネリック。観察は `@ObservedObject` のみ。サブビューは Presenter 全体を受け取らず、コントロールが要求する Binding アダプタと、リスト行の Intent クロージャを使い分ける。
- **Presenter**: `@MainActor`。`viewState`（計算の正本）、`sessionChrome`（復元・セット）、`collectionState`（席の済/未済。計算しない）を `@Published` で公開する。入力 Intent のたびに計算を 1 回行う。チェック操作は計算しない。シェア文面は `viewState.shareText`、入力バリデーションもここ。
- **Interactor**: `SakuttoSplitInteractorProtocol` に適合。`BillCalculationInput` を受け、`BillCalculationOutput` を返す同期の純関数。
- **Entity**: `AttendeeGroup`（ドメイン）、`AttendeeGroupDraft`（TextField 用）、`PaymentMode`、`RoundingUnit`、計算の入出力。
- **Router**: `SakuttoSplitModule`（Presenter、`AdsController`、banner / interstitial / rewarded の 3 ID）を返す。`AnyView` は使わない。
- **App**: `assembleModule()` は `init` のみ。Presenter と `AdsController` を `@StateObject` で所有する。SDK `start` 完了後に `startLoadingIfNeeded`。
- **Ads**: 資格判定は `AdEligibility`、広告オフ期限は `AdFreeStore`（UserDefaults）。`GoogleMobileAds` の import は App / `AdBannerView` / `AdsController` のみ。計算 Presenter は広告 SDK を知らない。
- **Session**: 前回会計・メンバーセット・直近 5 件の履歴・オファー消費・通知プロンプト済みは `BillSessionStore`（UserDefaults、`session.*`）。Presenter は Store に依存し、SDK も `UserNotifications` も import しない。
- **Reminders**: 発火時刻は `UnpaidReminderSchedule`。本番の予約は `UnpaidReminderScheduler` のみが `UserNotifications` を import する。テストは Null / Spy。
- **Config**: 広告ユニット ID（`AdConfiguration`。DEBUG と TestFlight は Google テスト ID、App Store 本番だけ本番 3 ID）、入力上限（`InputLimits`）、表示用円フォーマット（`YenFormatting`。入力・Snapshot の正本は数字文字列のまま）。人数は 1...999（空欄・0・非数字は UI で `"1"` に正規化）。

プロトコルは `SakuttoSplitContract.swift` に集約し、Presenter / Interactor はプロトコル経由で差し替えできるようにしています。

## 品質担保
`SakuttoSplitTests` で Interactor / Presenter / Router / Entity 変換 / 入力正規化を `XCTest` しています。テストファイル名とクラス名は対応させています。

- Interactor: 均等割り、固定額と割合の混合、端数単位、空入力、固定額超過、同名グループなど
- Presenter: 入力正規化、1 Intent = 1 計算、シェア文、バリデーションとシェア可否、精算時の前回保存、復元、メンバーセット Undo、回収チェックと全員済（計算 0 回）、席の増減と済の引き継ぎ
- 計算結果の identity はグループ名ではなく `groupID`
- 広告: 資格判定・精算リセット・広告オフ期限。リワード目的（24h オフ / 保存枠）は分離。SDK 本体は叩かない
- 永続化: 壊れた JSON は空扱い。Store は `UserDefaults(suiteName:)` でテストする。履歴は直近 5 件。同一グループ ID 列は上書き
- 未払いリマインダー: 発火時刻の純関数。スケジューラは Spy。`UNUserNotificationCenter` の本物は叩かない

## 広告
割り勘の「サクッと」を維持するため、広告は入力の邪魔にならない位置と、ユーザーが自分で区切った直後にだけ出す。

- **バナー**: 画面最下部、Form の外。キーボード表示中（いずれかの入力がフォーカス中）は高さ 0 で畳み、確認中だけ出す。広告オフ中も畳む。SDK 未 ready かつキーボードなしのときは高さ 50 のプレースホルダ。入力のたびに再 load しない。
- **インタースティシャル**: 精算完了の確認を経た成功直後だけ。起動・シェア・チェック・入力・バックグラウンド復帰・確認キャンセルでは出さない。起動から 15 秒未満、未 load、このプロセスで既に 1 回出した、広告オフ中は出さず、リセットだけ行う。待ちダイアログは出さない。
- **リワード**: 右上 Menu の「今日の広告をオフ」。最後まで見ると 24 時間、バナーとインタースティシャルの両方を止める。途中閉じでは付与しない。未 load なら「広告を読み込めませんでした」と短く伝え、落とさない。編成の保存枠を増やす動画は Menu の保存からで、広告オフは付かない。
- **出さないもの**: App Open、起動時全画面、シェア前後の全画面、ATT ダイアログ（v2.0.0 は非パーソナライズ）。
- **ID**: DEBUG と TestFlight は Google 公式テスト ID。App Store 本番配信だけ AdMob 本番 3 ID（バナー / インタースティシャル / リワード）。`GADApplicationIdentifier` は変えない。

## 会計の継続
今夜の会計が消えないことと、よく使う編成を次も一発で出せることを、広告の隣に置く。

- **前回の会計を復元（無料）**: 精算完了の直前と、バックグラウンド遷移時に、妥当な入力だけ 1 件保存する。起動はいつも初期画面。初期画面では再開カード 1 タップ、入力中は左上（確認 Alert）。総額空の初期状態では、既存の前回を消さない。
- **メンバーセット**: グループ編成と端数単位を名前付きで保存する。総額は含めない。無料 1 件。動画を最後まで見ると枠が 1 つ増え、最大 3。適用しても今の総額は変わらない。確認 Alert は出さず、直後の Undo で戻せる。広告オフ用の動画とは報酬が混ざらない。セットが 0 件のとき、初回のメインシェア後にだけ回収ボード先頭へ保存カードを出す。閉じるか保存すると再表示しない。

## 未払いのローカル通知
シェアしたあとの PayPay 待ちを、アプリを閉じたあとも 1 回だけ思い出させる。**ローカル通知のみ**。サーバーは持たない。毎日の配信やマーケティング通知ではない。

- 未払いが残る会計でメインシェアした直後、インストール 1 回だけ説明 Alert を出す。許可したときだけ、3 時間後（0:00–8:59 に当たればその日 10:00）に 1 通。
- 識別子は固定 1 つ。人数が変われば本文を置き換える。全員済または精算完了で予約を消す。
- 通知タップは通常起動だけ。前回会計の自動復元はしない。

## 会計の履歴
妥当な会計は前回 1 件に加え、直近 5 件を端末内に残す。起動はいつも初期画面。Menu の「会計の履歴」シートから、その会計を続ける（総額・済も戻る）か、同じ編成で始める（総額は空）ができる。

## 回収ボード
シェアしたあとの PayPay 待ちを、頭と LINE ではなくアプリで持つ。**無料**。総額入力からメインシェアまでのタップ数は増やさない。

- **席**: グループ人数から自動展開する（例: 一般×4 → 一般 1…4）。個人名の手入力はしない。**21 人以上のグループは 1 行**で済/未済。チェック UI。2 席以上のグループに「全員済」。計算しない。
- **位置**: 計算結果の下、精算完了の上（Form 内）。メインシェアは Form 外の sticky。総額空など妥当でない入力では出さない。
- **未払いだけ再シェア**: 二次ボタン（`.bordered`）。済の席は文面に出さない。全員済では出せない。メインのシェア文面は変えない。
- **保存**: 済/未済は前回会計に乗る。保存点は精算完了の直前とバックグラウンド。起動はいつも初期画面。

## スクリーンショット
| 入力画面 | 計算結果とシェア |
| --- | --- |
| <img width="1206" height="2622" alt="output" src="https://github.com/user-attachments/assets/c3da3e5a-9ef9-418c-8f72-0ce275ade20c" /> | <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-05-05 at 22 13 20" src="https://github.com/user-attachments/assets/4cd23f1f-0df8-421f-9661-64961945e8df" />

提出ショットは、ヒーロー総額 + 再開カード（前回ありの初期画面）と、妥当入力後の sticky シェアと回収チェックを含める。

## 提出前の目視
1. 起動。VoiceOver オフなら総額キーボード。バナーなし。シェアは toolbar。完了後、sticky がバナー直上
2. 部長/一般のまま 35000。スクロールせずシェア。文面がレシート調。LINE にカンマがある
3. ホームへ。再起動は initial + 再開カード。カード 1 タップで金額と済が戻る。左上復元は出ない
4. 総額をいじるとカードが消え、左上復元が出る。確認 Alert は dirty のみ
5. Menu から編成を適用。Alert なし。Undo で戻る。総額は維持
6. 回収をチェック。スイッチ UI ではない。一般を全員済にできる。未払い再シェアは bordered
7. 精算を開きキャンセル。画面も広告も変わらない。実行すると initial +（15 秒後なら）全画面
8. キーボード中バナーなし。シェアやチェックでは全画面なし
9. セット 0 でメインシェア。回収先頭に編成カード。保存名が「いつもの飲み会」。保存後は再起動しても出ない
10. 未払いがある状態でシェア。許可 Alert。あとでは OS の通知許可を出さない。許可後に全員済で pending が消える
11. 宴会を 2 回精算。履歴 2 件。同じ編成で始めると総額空。続けると総額と済が戻る。起動は initial

## 開発者
- mw-wakkun

## 配信

SakuttoSeat と同じ Fastlane 構成。認証は App Store Connect API Key（`.p8`）。Apple ID ログインは使わない。

1. `fastlane/.env.example` を `fastlane/.env` にコピーし、`ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_FILEPATH` を埋める（`.env` は Git 管理外）
2. TestFlight（内部テスター、ビルド番号だけ +1、Git 操作なし）:

```sh
bundle exec fastlane ios beta
```

3. App Store 申請用アップロード（版指定、タグと GitHub Release まで）:

```sh
bundle exec fastlane ios release version:2.0.0
```

再アップロードだけするときは `skip_increment:true`。同一ビルド番号の再送は App Store Connect が拒否する。
TestFlight の広告は Google 公式テスト ID。本番広告は App Store 配信だけ。
