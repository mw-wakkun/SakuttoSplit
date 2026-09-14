# SakuttoSplit v2.0.0 広告実装計画書

- 対象: 現行の単一 VIPER モジュール `Modules/SakuttoSplit` と、その依存（`App` / `Config` / `Components`）への広告拡張
- 作成日: 2026-09-14
- 前提: VIPER リファクタ（`refactor_splitView.md`）と健康診断フォロー（`refactor.md`）は完了済み
- 入力: v2.0.0 広告戦略（現行導線分析 / UX 非破壊の配置 / 将来のリワード種）
- 方針: **この文書ではコード実装を行わない**。実装者が迷わないよう、仕様・責務・手順・完了条件だけを固定する
- 評価観点: UX を落とさないこと / 計算ロジックを変えないこと / VIPER の境界を壊さないこと / AdMob ポリシーに違反しないこと

本バージョンの目的は、割り勘計算の「サクッと」を維持したまま、**心理的区切りと任意の報酬にだけ** 広告を乗せる基盤を入れることである。将来のテンプレ・履歴・OCR・画像シェアは範囲外（開発ストックとして末尾に残す）。

---

## 1. 現状サマリ

アプリは 1 画面のリアルタイム割り勘計算機である。画面遷移はなく、`NavigationStack` はタイトル用。計算は入力のたびに走り、妥当な入力になると緑のシェアボタンが有効になる。シェア文は PayPay 等での回収を前提にしており、**シェア後も結果画面が現場の台帳になる**。

| 項目 | 現状 |
| --- | --- |
| 画面 | `SakuttoSplitView` のみ |
| 広告 | 画面最下部のバナー 50pt。`MobileAds.shared.start()` 完了後に load |
| 広告 ID | `AdConfiguration.bannerAdUnitID` のみ（DEBUG は Google テスト ID） |
| リセット | なし。二次会の会計を始める導線がない |
| シェア完了の検知 | なし。`ShareLink` を View が直接持つ |
| 計算 | Interactor 純関数。1 Intent = 1 計算 |
| キーボード | `SakuttoSplitFocus` + toolbar「完了」 |

既存バナー実装（Form 外・`equatable()`・SDK start 後 load）は維持する。壊してはいけない。

---

## 2. プロダクト方針（先に決めること）

実装中にひっくり返さない。戦略レポートの結論を、実装契約としてここに固定する。

### 2.1 採用する

| 判断 | 理由 |
| --- | --- |
| バナーは残す。**キーボード表示中は出さない** | 入力の邪魔と誤タップ（無効トラフィック）を同時に防ぐ。確認・PayPay 待ちでは出す |
| インタースティシャルは **「精算完了」タップ後だけ** | シェア直後だと金額台帳が隠れる。起動直後だと「サクッと」が死ぬ |
| 「精算完了（次の会計へ）」CTA を結果セクション末尾に追加する | 広告のためだけでなく、二次会のリセット不足を解消する |
| リワードは **「動画を見て、今日の広告をオフ」だけ** | 現行機能はすべて無料。偽のロックは作らない |
| 広告オフはバナー **と** インタースティシャルの両方 | 「消したつもりなのに全画面が出る」が最悪の体験だから |
| 広告 SDK / 提示は Presenter の計算から分離する | GoogleMobileAds を計算 Presenter に入れない |
| ロード未完了なら広告を出さず、リセットだけ行う | 広告待ちで画面を止めない |
| 計算仕様・初期グループ・シェア文面は変えない | 広告 PR に精算ロジックを混ぜない |

### 2.2 採用しない（v2.0.0 禁止）

| 判断 | 理由 |
| --- | --- |
| App Open 広告 | 起動の速さが商品。LINE から戻った直後も禁止 |
| 起動時インタースティシャル | AdMob ポリシーとブランドの両方に反する |
| シェア前 / シェアシート閉直後の全画面 | コア CTA を殺す。戻った瞬間に金額が消える |
| 入力中・グループ追加削除・端数変更での全画面 | 作業中の割り込み |
| Form 内・結果数字の直下へのバナー / ネイティブ | 計算結果と誤認される |
| グループ数制限などの偽リワード | いま無料のものを有料化して見せる行為 |
| ATT ダイアログを初回起動で出す | 会計前の待ち時間になる。v2.0.0 は非パーソナライズで出す |
| IAP（広告削除の買い切り） | 次バージョン。今回はリワード 24h オフまで |
| 履歴・テンプレ・OCR・画像シェア | 開発ストック。v2.0.0 の完了条件にしない |

### 2.3 UX の絶対ルール（レビュー観点）

実装者が迷ったら、ここに戻る。

1. 総額入力からシェアまでのタップ数を、今より増やさない。「精算完了」は任意
2. キーボード中にバナーが見えない
3. 1 人あたり金額は、常に広告より手前にある
4. 全画面は「精算完了」を自分で押した人にしか出ない
5. 広告の準備ができていなければ、待たせずに次へ進む
6. シェアボタンの視覚的優先度を下げない（緑・全幅・headline を維持）

---

## 3. 仕様

### 3.1 バナー

| 項目 | 仕様 |
| --- | --- |
| フォーマット | 現行の `AdSizeBanner` を維持してよい。Adaptive 化は任意（やるなら高さ変動で Form が跳ねないことを SE / Pro Max で確認） |
| 配置 | 現行どおり `SakuttoSplitView` の Form 外・画面最下部。Form の行の間に入れない |
| 表示 | `isAdsSDKReady == true` **かつ** `focusedField == nil` **かつ** 広告オフ期間外 |
| 非表示 | いずれかの TextField / 人数入力がフォーカス中。広告オフ期間中 |
| 非表示時の高さ | **0**。キーボード中は入力領域を優先する。広告オフ中もスロットを畳む |
| SDK 未 ready かつキーボードなし | 現行どおり高さ 50 のプレースホルダ（ジャンプ防止） |
| 再表示の合図 | toolbar「完了」またはフォーカス解除 |
| 再ロード | 入力のたびに `makeUIView` / `load` しない。現行の `equatable()` と Container の `didLoadAd` を維持 |

キーボード表示中にスロットを畳むと Form は伸びる。キーボードアニメーションと同時なので許容する。確認モードに戻ったときバナーが再出現する。

### 3.2 精算完了（新 CTA）

結果セクションの **シェアボタンの下** に置く。シェアより目立たせない（`.bordered` またはプレーン。緑全幅はシェア専用）。

| 項目 | 仕様 |
| --- | --- |
| 文言キー | `settle.complete` |
| デフォルト文言 | `精算完了（次の会計へ）` |
| 有効条件 | `validationIssue == nil`（シェアと同じ） |
| 無効時 | `.disabled` + シェア同様に opacity を下げてよい |
| タップ時 | 1. キーボードを閉じる 2. ViewState を `initial` に戻して 1 回計算 3. インタースティシャル資格があれば提示 4. 無ければ何も出さず入力画面へ |
| 確認ダイアログ | 出さない。ラベルで意図を示す |
| 完了演出 | 出してよいのは 1 秒以内のごく短いフィードバックのみ。必須ではない。広告待ちには使わない |

リセット後の状態は起動時と同一である。

- 総額空欄
- 端数 100 円
- グループ「部長」（固定 10000）と「一般」（割合 1.0 × 4）
- シェア無効（総額未入力）

計算期待値は `SakuttoSplitViewState.initial` を使うこと。手でフィールドを並べ直さない。

### 3.3 インタースティシャル

| 項目 | 仕様 |
| --- | --- |
| トリガー | `didTapSettleComplete` が成功した直後のみ（バリデーション通過時） |
| 提示の主体 | Ads 層（Router / AdsController）。計算 Presenter は GoogleMobileAds を import しない |
| 出す条件（すべて満たす） | 広告オフ期間外 / このプロセスで未提示 / 起動から 15 秒以上経過 / 広告が load 済み / rootViewController が取れる |
| 出さない | 上記のどれかが欠ける。その場合はリセットのみ |
| キャップ | **1 セッション（アプリプロセス）1 回** |
| プリロード | SDK start 完了後に 1 回。提示して閉じたら次をプリロード（次セッション用ではなく、同一セッションでは出さないが、次回起動に備えて load してよい） |
| 失敗 | エラーでもユーザーにアラートを出さない。リセットは既に完了している |

**禁止トリガー（回帰で見ること）:** 起動、バックグラウンド復帰、シェアタップ、Share シート dismiss、グループ操作、端数変更、初回バリデーション成功。

### 3.4 リワード（今日の広告オフ）

| 項目 | 仕様 |
| --- | --- |
| 入口 | ナビゲーション右上の toolbar ボタン |
| アイコン | `video.slash` または `nons.slash` 系。長押しなしの単一ボタン |
| accessibility | `ads.hide_for_today` の文言をラベルにする |
| 文言 | `動画を見て、今日の広告をオフ` |
| 再生 | ユーザーがボタンを押したときだけ。自動再生禁止 |
| 報酬付与 | **リワード完了コールバックが成功したときだけ**。途中閉じは付与しない |
| 報酬 | 付与時刻から 24 時間、バナー非表示かつインタースティシャル抑制 |
| 永続化 | `UserDefaults`（キーは `ads.adFreeUntil` など 1 箇所に定数化） |
| 期限切れ | 次回バナー表示判定時に通常へ戻す。期限切れ専用のダイアログは出さない |
| オフ期間中のボタン | 「広告オフ中（残り時間）」を出すか、ボタンを隠す。残り時間表示が望ましい |
| ロード失敗 | ボタンは押せるが、未 load なら提示せず、短く失敗を伝える（バナー領域や toolbar の一時テキスト）。クラッシュさせない |
| オフ中に精算完了 | リセットはする。全画面は出さない |

コピーのトーンは居酒屋の幹事向け。「プレミアム解放」のようなゲーム文言は使わない。

### 3.5 セッションと時刻

| 値 | 定義 |
| --- | --- |
| セッション | プロセス起動から終了まで。バックグラウンド往復ではリセットしない（LINE 往復で再提示しないため） |
| 15 秒ゲート | AdsController 生成時刻（≒ SDK 利用開始）からの経過 |
| 24 時間 | `Date() + 86400`。壁時計。タイムゾーン変更は無視してよい |

### 3.6 ローカライズ

`Localizable.xcstrings` に追加する。ソース言語は現行どおり en キー + 日本語 value。

| キー | value |
| --- | --- |
| `settle.complete` | `精算完了（次の会計へ）` |
| `ads.hide_for_today` | `動画を見て、今日の広告をオフ` |
| `ads.off_remaining` | `広告オフ中`（残り時間を出すなら `ads.off_remaining %lld` など実装時に 1 キーに決める） |
| `ads.reward_unavailable` | `広告を読み込めませんでした` |

シェア文・計算結果・バリデーション文言は変更しない。

### 3.7 AdMob ユニット ID

`AdConfiguration` が 3 ID を持つ。DEBUG は Google 公式テスト ID を使う。本番 ID は AdMob コンソールで **新規作成** し、この計画書のプレースホルダを埋めてから Release ビルドする。バナー本番 ID は現行を流用する。

| 枠 | DEBUG | Release |
| --- | --- | --- |
| Banner | `ca-app-pub-3940256099942544/2934735716`（現行） | `ca-app-pub-9676260030977388/3738962239`（現行） |
| Interstitial | `ca-app-pub-3940256099942544/4411468910` | **要発行**（未発行のまま Release しない） |
| Rewarded | `ca-app-pub-3940256099942544/1712485313` | **要発行** |

`GADApplicationIdentifier`（`ca-app-pub-9676260030977388~1564525389`）は変更しない。

SKAdNetwork: 現行 `Info.plist` は `cstr6suwn9.skadnetwork` のみ。v2.0.0 で AdMob 公式の最新 SKAdNetwork リストへ更新する（実装時点の Google ドキュメントを正とする）。ATT 用 `NSUserTrackingUsageDescription` は v2.0.0 では追加しない。

---

## 4. アーキテクチャ

計算 VIPER を広告 SDK で汚さない。広告は並走する小さなモジュールとして組む。

```text
App
  ├─ @StateObject SakuttoSplitPresenter     … 割り勘の正本
  ├─ @StateObject AdsController             … 広告の正本（新設）
  ├─ AdConfiguration（3 ID）
  └─ isAdsSDKReady

SakuttoSplitView
  ├─ 描画と Intent 転送（計算）
  ├─ focusedField でバナースロットの表示切替（View ローカル）
  ├─ 精算完了 → presenter.didTapSettleComplete()
  └─ 広告オフ → adsController.didTapHideAdsForToday()

Presenter（計算）
  ├─ didTapSettleComplete() で state = .initial + 再計算
  └─ 完了後に adsRouting.presentInterstitialIfEligible()
     GoogleMobileAds は import しない

AdsController
  ├─ SDK start 後の interstitial / rewarded load
  ├─ 提示資格（15 秒、1 セッション 1 回、広告オフ期限）
  ├─ UserDefaults の期限読み書き
  └─ UIKit 提示に必要な rootViewController 解決

Router.assembleModule()
  └─ presenter + adsController + AdConfiguration を返す
```

### 4.1 責務の境界

| やってよい層 | 内容 |
| --- | --- |
| Config | 3 つのユニット ID。DEBUG/Release 切替 |
| AdsController（新設） | load / present / キャップ / 広告オフ期限。`GoogleMobileAds` はここだけ（バナー View を除く） |
| Router | 組み立て。Presenter に `adsRouting` を渡す |
| Presenter | 精算完了のリセットと、routing プロトコル経由の「区切り通知」だけ |
| View | フォーカスに応じたバナー可視、精算ボタン、toolbar。資格判定ロジックは持たない |
| Interactor / Entity | **変更しない** |

### 4.2 プロトコル

`AdConfigurationProviding` を拡張する。

```text
bannerAdUnitID: String
interstitialAdUnitID: String
rewardedAdUnitID: String
```

提示の抽象（名前は実装時に短くしてよい）。

```text
@MainActor
protocol AdsRouting: AnyObject {
    func presentInterstitialIfEligible()
}

@MainActor
protocol AdsControlling: ObservableObject {
    var isAdFree: Bool { get }
    var canRequestRewarded: Bool { get }  // UI 用。未 load でもボタンは出してよい
    func startLoadingIfNeeded()
    func didTapHideAdsForToday(from rootViewController: UIViewController)
    func presentInterstitialIfEligible(from rootViewController: UIViewController)
}
```

Presenter が持つのは `AdsRouting` だけにする。`AdsController` が `AdsRouting` を満たすなら、Presenter は「精算した」と伝える以上の広告知識を持たない。

`rootViewController` の取得は現行バナーと同じ方針とする。`UIApplication` の windows 探索を増やさず、提示時点の View / window から取る。AdsController に VC を渡すのは View（またはバナーと同様の UIKit ラッパ）からでよい。

推奨の Sequential フロー:

1. View が精算完了を Intent する
2. Presenter がリセットする
3. Presenter が `adsRouting.presentInterstitialIfEligible()` を呼ぶ
4. AdsController が資格を見て、必要なら View 側から渡済みの presenter VC で present する

VC の受け渡し方法は次のどちらかに統一する（混在させない）。

- A: App / View の `safeArea` に載せない UIKit ホストが AdsController に VC をセットする
- B: `presentInterstitialIfEligible` を View が AdsController に対して直接呼ぶ。その場合 Presenter はリセットのみ、View が「リセットの直後に present を呼ぶ」

**採用: A が難しければ B でよい。** SwiftUI 単画面では B の方が実装事故が少ない。その場合の契約は次で固定する。

- View の精算ボタン: `presenter.didTapSettleComplete(); adsController.presentInterstitialIfEligible(from:)`
- Presenter は広告を知らない
- 「リセットしてから広告」の順序は View が保証する。リセットは同期なので問題にならない
- この例外は README に 1 行書く（シェアが View の `ShareLink` であるのと同様、OS/SDK 提示は View 境界）

計算 Intent の純度を守る方が、無理な Router 循環より優先である。

### 4.3 ViewState

割り勘の `SakuttoSplitViewState` に広告フラグを入れない。入れると入力のたびに広告状態と比較され、責務が混ざる。広告オフは `AdsController` の `@Published` とする。

精算完了の無効化は既存の `validationIssue` を使う。新しい ViewState フィールドは不要。

### 4.4 ファイル配置（予定）

既存の置き場に合わせ、広告 SDK を知る型は `Components` か新ディレクトリ `Ads` に集める。`Modules/SakuttoSplit` の Interactor には置かない。

| ファイル | 役割 |
| --- | --- |
| `Config/AdConfiguration.swift` | 3 ID |
| `Ads/AdsController.swift`（新設） | load / present / 期限 / キャップ |
| `Ads/AdFreeStore.swift`（新設・任意） | UserDefaults の読み書きを Controller から分離する場合 |
| `Components/AdBannerView.swift` | 現行維持。表示切替は親 View |
| `Modules/SakuttoSplit/View/SakuttoSplitView.swift` | バナースロット条件、toolbar |
| `Modules/SakuttoSplit/View/Subviews/SettleCompleteButton.swift`（新設） | 精算完了行。`ShareResultButton` に相乗りしない |
| `Modules/SakuttoSplit/View/Subviews/CalculationResultSection.swift` | 精算ボタンを末尾に追加 |
| `Modules/SakuttoSplit/Presenter/SakuttoSplitPresenter.swift` | `didTapSettleComplete` |
| `Modules/SakuttoSplit/Contract/SakuttoSplitContract.swift` | Intent 追加、Ad プロトコル拡張 |
| `Modules/SakuttoSplit/Router/SakuttoSplitRouter.swift` | Module DTO に AdsController と 3 ID |
| `App/SakuttoSplitApp.swift` | AdsController 所有、SDK start 後に load 開始 |
| `Info.plist` | SKAdNetwork 更新 |
| `Localizable.xcstrings` | 新キー |

`ShareResultButton` を `.equatable()` で包まない制約は維持する（`listRowBackground` が落ちる既知理由）。精算ボタンは背景を緑にしない。

---

## 5. フェーズ

フェーズごとに PR を切る。計算期待値を変えるコミットと広告コミットを混ぜない。

### フェーズ 0: 契約とテストの先書き

目的: 仕様をテストで固定してからプロダクトを動かす。

実施内容:

1. `AdConfigurationProviding` に interstitial / rewarded ID を足すテスト（スタブ注入）
2. Presenter: `didTapSettleComplete` が `validationIssue != nil` のときは state を変えない（呼び分けは View でもよいが、Presenter 側でもガードする）
3. Presenter: 妥当な状態で精算すると `viewState ==` 計算済み initial（`initial` に `applyCalculation` した形）
4. Ads 資格の純ロジックを SDK なしでテストできる型に切り出す
   - 広告オフ期限内 → interstitial NG、banner NG
   - セッション内提示済み → interstitial NG
   - 経過 14 秒 → NG、15 秒 → OK（境界は `>= 15`）
   - 未 load → NG
5. 本番 ID が空文字のまま Release ビルドできないことは、このフェーズではテストしなくてよい（コンソール発行待ち）。DEBUG テスト ID の非空はテストする

完了条件:

- 新規テストが Red でも、既存 Interactor / Presenter 計算テストはグリーンのまま
- プロダクトの画面はまだ変わらない（ID プロパティ追加だけは可）

### フェーズ 1: バナーをキーボード連動にする

目的: 作業妨害を先に消す。収益枠は残す。

実施内容:

1. `SakuttoSplitView.adBannerSlot` の表示条件を 3.1 どおりにする
2. 広告オフはまだ常に false でよい（AdsController 未接続なら `isAdFree = false` 固定）
3. フォーカス中に高さが 0 になること、完了で 50 に戻ることを目視する
4. 入力中に広告リクエストが増えないことを、現行どおり `equatable()` で維持する

完了条件:

- 総額入力中にバナーが見えない
- 完了後（結果確認中）にバナーが見える
- 入力 1 文字でバナーが再 load しない（現行テスト `AdBannerView` Equatable を維持）

### フェーズ 2: 精算完了とリセット

目的: 心理的区切りをプロダクトとして先に作る。広告はまだ出さない。

実施内容:

1. `SettleCompleteButton` を追加し、`CalculationResultSection` のシェア下に置く
2. `SakuttoSplitPresenterProtocol.didTapSettleComplete()`
3. 実装は `viewState` を initial に戻し `applyCalculation`
4. 無効時は押せない
5. xcstrings を追加
6. シェアボタンの見た目・文言・有効条件は不変であること

完了条件:

- 総額入り・妥当なグループで精算すると、起動時と同じ入力に戻る
- 総額空欄では押せない
- シェアはこれまで通り動く
- このフェーズでは全画面広告が 1 回も出ない

### フェーズ 3: インタースティシャル

目的: 精算完了の直後にだけ全画面を出す。

実施内容:

1. AdsController を組み立てに乗せる
2. SDK start 完了後に interstitial を load（App の `.task` から `startLoadingIfNeeded`）
3. 精算完了の直後、資格を満たせば present
4. 資格を満たさなければリセットのみ（フェーズ 2 の挙動）
5. DEBUG はテスト ID
6. 起動直後 15 秒以内の精算では出ないことを確認する

完了条件:

- 起動直後に全画面が出ない
- シェアでは出ない
- 入力中に出ない
- 精算完了かつ 15 秒経過かつ load 済みかつオフ期間外のとき、1 セッション 1 回だけ出る
- load 失敗時はリセットだけされ、アラートがない

### フェーズ 4: リワード 24h オフ

目的: ユーザー起点の報酬だけを足す。

実施内容:

1. toolbar ボタン
2. 視聴完了で `adFreeUntil = now + 24h` を永続化
3. `isAdFree` がバナーとインタースティシャルの両方を止める
4. 途中閉じで期限が書き換わらない
5. アプリ再起動後も期限中はオフ
6. 失敗コピー `ads.reward_unavailable`

完了条件:

- 押していないのに動画が始まらない
- 完了時だけバナーが消え、スロット高さが 0 になる
- オフ中の精算完了で全画面が出ない
- 24h 後（テストは短い interval を注入可能にすること）にバナーが戻る

テスト用に `now: () -> Date` と `adFreeDuration` を差し替え可能にする。本番 default は 24h。

### フェーズ 5: 仕上げ

目的: 配布できる状態にする。

実施内容:

1. AdMob コンソールで interstitial / rewarded の本番 ID を発行し `AdConfiguration` の Release に入れる
2. `Info.plist` の SKAdNetwork を AdMob 最新リストへ
3. README に広告の出し方（キーボード中非表示、精算完了のみ全画面、任意リワード）を 1 節で追記
4. シミュレータでテスト ID の 3 フォーマットを目視
5. 実機 DEBUG で 1 通す（rootViewController・ATT なしでも表示されること）

完了条件:

- Release の 3 ID がすべて非空
- README が実装と一致
- セクション 9 の完了定義を満たす

---

## 6. ファイル別対応マップ

| 現状 | 変更 | フェーズ |
| --- | --- | --- |
| `AdConfigurationProviding.bannerAdUnitID` のみ | interstitial / rewarded を追加 | 0–1 |
| `SakuttoSplitModule.bannerAdUnitID` | 3 ID + AdsController を載せる | 0, 3 |
| `adBannerSlot` 常時 50pt | フォーカス / 広告オフ / SDK ready で出し分け | 1, 4 |
| 結果セクション末尾がシェア | 精算完了ボタンを追加 | 2 |
| Presenter にリセット Intent なし | `didTapSettleComplete` | 2 |
| 広告提示クラスなし | `AdsController` | 3–4 |
| toolbar なし（キーボード以外） | 広告オフ | 4 |
| `Info.plist` SKAdNetwork 1 件 | AdMob 公式リスト | 5 |
| README の広告説明がバナーのみ | v2.0.0 の 3 フォーマット方針 | 5 |

触らないもの:

- `SakuttoSplitInteractor` の計算式と端数アルゴリズム
- デフォルトグループ（部長 10000 / 一般 1.0 × 4）
- 既存バナー本番 ID と `GADApplicationIdentifier`
- `ShareTextBuilder` の日本語
- `ShareResultButton` の緑背景と `.equatable()` 禁止
- 人数 1...999、総額 8 桁、1 Intent = 1 計算
- App の Presenter `@StateObject` 所有

---

## 7. テスト計画

SDK を叩くテストは書かない。資格判定とリセットと Config 注入を単体テストする。

| 対象 | フェーズ | 内容 |
| --- | --- | --- |
| AdConfiguration / Router | 0 | 3 ID が空でない。スタブ注入が banner / interstitial / rewarded すべてに効く |
| Presenter | 2 | 精算完了で initial + 計算済みに戻る。総額空・グループ 0・固定額超過では state 不変 |
| Presenter | 2 | 精算完了は計算 1 回（spy）。リセットのためにループしない |
| AdEligibility（純関数または AdsController の logic） | 0, 3 | 15 秒境界、セッション 1 回、adFree 中、未 load |
| AdFreeStore | 4 | 保存した期限を読む。`now` が期限内なら `isAdFree == true`、期限後は false |
| Rewarded 付与 | 4 | 完了フラグが true のときだけ期限を書く。中断では書かない |
| View 契約 | 2 | `SettleCompleteButton` の enabled が `validationIssue == nil` と一致（Preview または単純な View テスト） |
| 既存 | 全期間 | Interactor / シェア文 / 人数正規化 / Result identity を壊さない |
| 手動 | 1, 3, 4, 5 | 下記チェックリスト |

手動チェックリスト（実装者 / レビュー）:

1. 起動してすぐ総額を入れる。バナーが見えない。全画面が出ない
2. 「完了」でキーボードを閉じる。バナーが見える
3. シェアシートを出して閉じる。全画面が出ない。金額が見える
4. 起動 15 秒以内に精算完了。リセットされるが全画面なし
5. 15 秒後に再度会計して精算完了。全画面 1 回。もう一度会計して精算しても全画面なし
6. 広告オフを最後まで見る。バナーが消える。精算しても全画面なし。再起動してもオフのまま
7. 広告オフを途中で閉じる。バナーは残る
8. オフラインまたは load 失敗。精算完了で落ちない、ダイアログで止まらない

---

## 8. リスクと移行方針

| リスク | 対策 |
| --- | --- |
| 精算完了をシェアと押し間違える | シェアを緑全幅のまま最優先。精算は二次ボタンで下に置く |
| リセットで二次会の入力が消える | 仕様どおり。v2.0.0 に履歴はない。ラベルで「次の会計へ」と明示 |
| バナー高さ 0 でレイアウトジャンプ | キーボードアニメーション中のみ。広告オフ時はユーザー操作の結果なので許容 |
| Adaptive Banner で高さが 50 を超える | フェーズ 1 は `AdSizeBanner` 維持。変えるならフェーズ 5 で実機確認 |
| Presenter に AdMob が染みる | import の grep をレビュー観点にする。許可は App / Ads / AdBannerView のみ |
| テストが本番広告を叩く | Controller をプロトコル化。ユニットテストは stub |
| Release ID 未発行で出す | フェーズ 5 のゲート。未発行なら Debug のみマージ可、Store 提出不可 |
| SKAdNetwork 不足で収益が落ちる | フェーズ 5 で公式リストへ |
| LINE 往復で App Open 相当の再提示 | App Open を入れない。セッションをプロセス寿命にする |
| 無効クリック | キーボード中バナー非表示が主対策。結果数字の上にバナーを置かない |
| `rootViewController` が nil | 出さない。クラッシュさせない。現行バナーと同じ window 起点 |
| 巨大 PR | フェーズ 0→5 で分割。2 までで「区切り CTA」が単体として価値を持つ |

ブランチ戦略（推奨）:

1. `feat/v2-ads-contracts`（フェーズ 0）
2. `feat/v2-banner-focus`（フェーズ 1）
3. `feat/v2-settle-complete`（フェーズ 2）
4. `feat/v2-interstitial`（フェーズ 3）
5. `feat/v2-rewarded-ad-free`（フェーズ 4）
6. `feat/v2-ads-release-ids`（フェーズ 5）

---

## 9. 完了の定義

v2.0.0 の実装完了とは、次をすべて満たす状態を指す。

1. キーボード表示中にバナーが出ない。確認中（フォーカスなし）には出る
2. 全画面広告は「精算完了」成功後にしか出ない。起動・シェア・入力では出ない
3. 全画面は 1 セッション 1 回。起動 15 秒未満、未 load、広告オフ中は出さない
4. 未 load でも精算完了はリセットされ、待ちダイアログがない
5. リワードはユーザー操作でのみ始まり、完了時だけ 24h 広告オフ（バナー + インタースティシャル）
6. 計算 Interactor・初期グループ・シェア文・人数仕様が v1 と同一
7. `SakuttoSplitPresenter` が `GoogleMobileAds` を import しない
8. DEBUG は Google テスト ID、Release は 3 枠とも本番 ID
9. README が上記の出し方と一致している

---

## 10. 実装時のレビュー用 grep

PR で次を確認する。

```text
import GoogleMobileAds
```

許可ファイル: `SakuttoSplitApp.swift`、`AdBannerView.swift`、`AdsController.swift`（およびそのテスト Double 以外）。

```text
presentInterstitial / InterstitialAd / RewardedAd
```

呼び出し元が精算完了経路と toolbar リワード以外にないこと。

```text
didTapSettleComplete
```

`validationIssue != nil` で state が変わらないこと。

---

## 11. 同一リリース（2.0.0）の第2スライス / 出荷後のストック

**Store の 2.0.0 は広告（本ファイル）・会計継続（`SakuttoSplit_v2.1.0.md`）・回収ボード（`SakuttoSplit_v2.2.0.md`）をまとめて出す。** 会計継続と回収の仕様は各スライス計画を正とする。広告だけを 2.0.0 として先に提出しない。

2.0.0 にまだ含めない残り（出荷後）:

| 機能 | リワード | プレミアム（将来 IAP） |
| --- | --- | --- |
| 端数の四捨五入 / 切り上げ | 今回だけ | 常時 |
| シェア画像カード | 1 枚（透かしなし） | テーマ |
| レシート OCR | 月 N 回 | 無制限 |
| 複数店舗の合算 | 2 件目追加 | 無制限 |
| 端数担当ルーレット | 1 回 | 演出・履歴 |
| 個人名への展開 | N 人まで | 無制限 |

IAP は買い切り（目安 480–980 円）を先に検討する。サブスクは頻度の低いユーティリティに合わない。リワードは「今夜だけ」、IAP は「毎月幹事」の二層にする。

---

## 12. 次のアクション

第1スライス（本ファイル）と第2スライス（会計継続）は完了済み。実装者は `SakuttoSplit_v2.2.0.md` のフェーズ 0 から回収ボードを始める。提出は第3スライス込みの **2.0.0 で一度だけ**。

---

## 13. 実施記録

（実装開始後にフェーズ完了を追記する）
