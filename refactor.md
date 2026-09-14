# VIPER 健康診断フォロー 修正計画書

- 対象: 単一 VIPER モジュール `Modules/SakuttoSplit` と、その依存（`App` / `Entity` / `Config` / `Components`）
- 作成日: 2026-09-14
- 前提: VIPER への構造リファクタ（`refactor_splitView.md` フェーズ 0–5）は完了済み
- 入力: 同日の横断診断レポート（契約の形骸化 / Presenter 所有権 / 旧 Bool API / 広告初期化競合 等）
- 方針: **この文書ではコード実装を行わない**。設計判断と段階的な改修手順のみを固定する
- 評価観点: 契約が実装と一致しているか / 寿命とクラッシュ耐性 / データの正本が 1 つか / 遺産の除去

前計画（`refactor_splitView.md`）は「フォルダ名 VIPER を実 VIPER にする」が目的だった。本計画は **できた VIPER を嘘のない状態に仕上げる** ことが目的である。計算仕様（端数切り捨て、固定額超過時の按分 0 など）は変えない。変える場合はテストを先に書き換える。

---

## 1. 現状サマリ

骨格は意図どおり動いている。

- View は描画と Intent 転送が中心
- Presenter は `@MainActor`、`viewState` を 1 つの `@Published` で公開し、計算入口は `applyUpdate` 1 箇所
- Interactor は Entity 入出力の同期純関数
- 結果 identity は `groupID`
- 古典的な VIPER 循環参照（View ⇄ Presenter ⇄ Router の相互強参照）はない

残っているのは「契約と実装の不一致」と「寿命・初期化の穴」である。単画面のうちは実害が小さいが、次の画面追加や App エントリの書き方変更で壊れやすい。

| 層 | 健全さ | 残課題 |
| --- | --- | --- |
| Contract | プロトコルはある | View / App / Router が具象直結。命名が 3 流儀。2 プロトコルは型として未使用 |
| View | サブビュー分割済み | 具象 `SakuttoSplitPresenter` 固定。シェア文だけ ViewState の外。`Binding` とクロージャが混在 |
| Presenter | Intent / 正規化 / 1 計算 | App が View を `@State` 保管し、Presenter は `@ObservedObject`（非所有）。`isFixed` 初期化が残る |
| Interactor | 純関数 | 変更なし（人数 0 はドメインとして残す） |
| Entity | ドメインと Draft 分離済み | Draft に死んだ `isFixed` getter/setter。`RoundingUnit.displayName` が UI 文言 |
| Router | `AnyView` なし | `assembleModule() -> View`。所有権を View 側に押し付けている |
| App | モジュールを `@State` で保持 | SDK `start` より先にバナー `load` が走りうる |
| 遺産 | 旧ファット View のファイルは削除済み | `isFixed`、空の xcstrings キー、`LetsSplitTheBill` 名残 |

---

## 2. 設計判断（先に決めること）

実装フェーズに入る前に、診断レポートの「使うか消すか」をここで決める。途中でひっくり返さない。

### 2.1 採用する

| 判断 | 理由 |
| --- | --- |
| Presenter の正本は App（またはモジュールルート）の `@StateObject` | `@ObservedObject` は観察専用。View を `@State` に入れて寿命を延命するのは SwiftUI の誤用 |
| Router は View ではなく **組み立て結果（Presenter + 広告設定）** を返す | View を返すと所有権が View に溶け、テストも所有も曖昧になる |
| View は `SakuttoSplitPresentable` に対してジェネリック | 契約を実体化できる。SwiftUI では `any ObservableObject` より associated なジェネリックが安全 |
| 表示データはすべて ViewState | `shareText()` メソッドを View が毎 `body` で呼ぶ状態を解消する |
| 人数の正本は `1...999`。空欄・0 は UI に残さない | `InputLimits.groupCountRange` とステッパーと計算入力を一致させる |
| 広告は `MobileAds.shared.start()` 完了後にだけ `load` | Google の推奨順。起動レースを消す |
| `AdConfigurationProviding` は使う | Router がプロトコル型で受け、具象 `AdConfiguration` をデフォルト注入する |
| シェア無効化は `.disabled`（または ShareLink 非表示） | `allowsHitTesting` だけでは VoiceOver から発火しうる |
| プロトコル命名は VIPER 3 役割を `*Protocol` に揃える | 既存の Interactor / Router に合わせ、Presenter だけ `Presentable` なのをやめる |

### 2.2 採用しない（過剰または時期尚早）

| 判断 | 理由 |
| --- | --- |
| `SakuttoSplitRouterProtocol` を残す | static 組み立てだけのプロトコルはモックできない。画面遷移が必要になるまで削除する |
| UIKit 的 ViewProtocol | struct View と合わない。前計画と同じ |
| Combine パイプライン化 | Intent メソッドで足りている |
| 入力デバウンス | 現行計算は軽い。前計画どおり不要 |
| 今すぐの本格多言語（英語 UI） | キー化と「ベタ書きを View/Builder に寄せる」まで。言語追加は別タスク |
| アプリ本体の Bundle ID 変更 | 配布中 ID `io.github.mw-wakkun.SakuttoSplit` は触らない。テスト側の旧名だけ対象 |
| Interactor の人数 0 禁止 | ドメイン API は防御的に 0 を受け続ける。UI が 0 を渡さなくする |

### 2.3 人数空欄の仕様（明示）

現行:

- ステッパー: `Int(text) ?? 1`
- Draft → Domain: `Int(countText) ?? 0`
- 正規化: 空文字と `"0"` を許可

**新仕様（UI / Presenter）:**

1. 人数テキストの正規化結果は常に `1...999` の十進文字列
2. 空文字・非数字・`0` は `"1"` にする
3. ステッパーの `??` デフォルトも 1 で、正規化後は空に戻らない
4. Interactor 単体テストの「人数 0」「不正文字列は 0」は **ドメイン直呼び** として残す（UI 経由では再現しなくなる）

これは仕様変更なので、フェーズ 0 で Presenter / InputLimits のテストを先に書き換えてからプロダクトを変える。

### 2.4 プロトコル最終形

```swift
@MainActor
protocol SakuttoSplitPresenterProtocol: ObservableObject {
    var viewState: SakuttoSplitViewState { get }
    func didChangeTotalAmount(_ text: String)
    func didChangeRoundingUnit(_ unit: RoundingUnit)
    func didChangeGroupName(id: UUID, name: String)
    func didChangeGroupCount(id: UUID, countText: String)
    func didChangePaymentMode(id: UUID, mode: PaymentMode)
    func didChangeFixedAmount(id: UUID, text: String)
    func didChangeRatio(id: UUID, text: String)
    func didTapAddGroup()
    func didTapRemoveGroup(id: UUID)
}

protocol SakuttoSplitInteractorProtocol {
    func calculateBill(_ input: BillCalculationInput) -> BillCalculationOutput
}

protocol AdConfigurationProviding {
    var bannerAdUnitID: String { get }
}
```

- `shareText()` はプロトコルから外し、`viewState.shareText` を正本にする
- `SakuttoSplitRouterProtocol` は削除
- `SakuttoSplitPresentable` は `SakuttoSplitPresenterProtocol` にリネーム（破壊的。モジュール外利用者はいない）

### 2.5 組み立てと所有

```
App
  @StateObject presenter   ← 所有の正本
  let bannerAdUnitID
  @State isAdsSDKReady
        │
        │ ObservedObject（観察のみ）
        ▼
SakuttoSplitView<Presenter: SakuttoSplitPresenterProtocol>
        │ Intent
        ▼
SakuttoSplitPresenter  ──calculateBill──► Interactor
        │
        ▼
  viewState（入力 + 結果 + shareText + validationIssue）
```

Router:

```swift
struct SakuttoSplitModule {
    let presenter: SakuttoSplitPresenter
    let bannerAdUnitID: String
}

enum SakuttoSplitRouter {
    @MainActor
    static func assembleModule(
        adConfiguration: any AdConfigurationProviding = AdConfiguration()
    ) -> SakuttoSplitModule
}
```

- `class Router` + インスタンスなし static だけ、はやめて `enum` にする（名前空間）
- App は `assembleModule()` の presenter を `StateObject(wrappedValue:)` で所有する
- `body` で `assembleModule()` を呼ばない（前計画の再発防止）

App での `@StateObject` 初期化は、プロパティ宣言のクロージャまたは明示 `init()` に閉じる。View を `@State` に入れない。

### 2.6 ViewState 最終形

```swift
struct SakuttoSplitViewState: Equatable {
    var totalAmountText: String
    var roundingUnit: RoundingUnit
    var groups: [AttendeeGroupDraft]
    var results: [GroupCalculationResult]
    var difference: Int
    var shareText: String
    var validationIssue: SplitValidationIssue?

    var isShareEnabled: Bool { validationIssue == nil }
}
```

- `shareText` は `applyCalculation` と同じ代入で更新する（1 Intent = 1 計算 = 1 シェア文）
- `isShareEnabled` は計算プロパティのまま。View には `validationIssue` だけ渡し、シェア可否はセクション内で導出してよい（二重渡し解消）
- 型名 `SplitValidationIssue` は互換より一貫性を優先し、`SakuttoSplitValidationIssue` にリネームする（使用箇所はモジュール内のみ）

### 2.7 Draft から Bool を消す

```swift
init(
    id: UUID = UUID(),
    name: String,
    countText: String = "1",
    mode: PaymentMode = .ratio,
    fixedAmountText: String = "0",
    ratioText: String = "1.0"
)
```

- `var isFixed` getter/setter 削除
- 既存の `isFixed: true` 呼び出しは `mode: .fixed` に置換
- 画面はすでに `PaymentMode` を使っているので UI 差分は出さない

---

## 3. 診断項目との対応

| 診断 | 重大度 | 本計画での扱い | フェーズ |
| --- | --- | --- | --- |
| View が具象 Presenter 直結 | 中 | ジェネリック View | 2 |
| プロトコル命名 3 流儀 | 中 | `*Protocol` に統一。Router プロトコル削除 | 2 |
| Router / Ad プロトコル未使用 | 中 | Ad は注入して使う。Router プロトコルは削除 | 2 |
| データ渡し 3 パターン | 中 | シェア文を ViewState へ。Binding は Intent アダプタとして残してよい | 1–2 |
| Presenter 所有が `@ObservedObject` + View の `@State` | 中 | `@StateObject` + Module DTO | 1 |
| `isFixed` 共存 | 軽〜中 | 削除 | 3 |
| 文言ベタ書き | 軽 | Entity から `displayName` を除去。新規グループ名はキー化。シェア文は Builder に残しキー化は任意 | 4 |
| `SplitValidationIssue` 等のプレフィックス | 軽 | Validation のみリネーム。汎用コンポーネント名は維持 | 4 |
| `validationIssue` と `isShareEnabled` の二重渡し | 軽 | セクションは issue だけ受ける | 2 |
| 広告 SDK より先に load | 中 | start 完了フラグ | 1 |
| 人数空欄の UI/計算不一致 | 軽 | 空・0 → `"1"` | 1 |
| シェアが `allowsHitTesting` のみ | 軽 | `.disabled` | 1 |
| `isFixed` デッドコード | 中 | 削除 | 3 |
| xcstrings 空キー `""` | 軽 | 削除 | 4 |
| `LetsSplitTheBill` 名残 | 軽 | テストバンドル ID と pbx の remoteInfo / 旧 productName コメントを現行名へ | 4 |
| `ShareResultButton: Equatable` が本番で未使用 | 軽 | Equatable はテスト用として残し、コメントを「包まない理由」に限定。削除しない | — |

循環参照そのものに対するコード変更はしない。`[weak self]` を足す場所はない。

---

## 4. フェーズ別計画

実装は **フェーズ 0 → 1 の順**。1 つの PR に寿命・仕様変更・リネームを混ぜない。

進捗:

- [x] フェーズ 0
- [x] フェーズ 1
- [ ] フェーズ 2
- [ ] フェーズ 3
- [ ] フェーズ 4

### フェーズ 0: 安全網（テストを先に固定 / 更新）

目的: 仕様を変える箇所だけテストを先に書き換え、変えない箇所はグリーンを維持する。

実施内容:

1. **変えないことを固定**（既存のままでよい）
   - Interactor: 端数、固定額超過、同名グループ、人数 0 のドメイン直呼び
   - Presenter: 1 Intent = 1 計算、総額 8 桁、倍率のドット 1 つ、シェア文面の現行日本語（文面変更はフェーズ 4 までしない）
2. **変えることを先にテストへ書く**（Red で止めてよいのはこのフェーズの新規テストだけ）
   - 人数: `didChangeGroupCount` に `""` / `"0"` / `"abc"` を渡すと `countText == "1"` になり、計算入力の `count == 1`
   - 人数: 同一正規化値なら再計算しない（`""` → `"1"` のあと再び `""` でも、表示が `"1"` のままなら計算 0 回追加）
   - Router: `assembleModule()` が View ではなく `presenter` と空でない `bannerAdUnitID` を返す
   - ViewState: `shareText` が総額変更と同時に更新される（メソッド `shareText()` 依存をやめる準備）
3. プロダクトコードはまだ変えない。フェーズ 1 でテストをグリーンにする。

完了条件:

- 新規テストが「期待する新仕様」を表現している
- 既存 Interactor テストは未変更でグリーンのまま

### フェーズ 1: 寿命・広告・人数・シェア無効化（実害）

目的: クラッシュと精算ミスの種を先に潰す。見た目の大きな変更はしない。

実施内容:

1. **Router**
   - `assembleModule() -> SakuttoSplitView` をやめ、`SakuttoSplitModule`（presenter + bannerAdUnitID）を返す
   - `adConfiguration: any AdConfigurationProviding = AdConfiguration()` を引数にする
   - 型を `enum SakuttoSplitRouter` にする
2. **App**
   - `@State private var splitView` を削除
   - `@StateObject` で `module.presenter` を所有
   - `bannerAdUnitID` は let（または同等の不変値）
   - `.task` で `MobileAds.shared.start()` 完了後に `isAdsSDKReady = true`
   - バナーは ready のときだけ読み込む（未 ready 時は高さ 50 のプレースホルダを残し、レイアウトジャンプを防ぐ）
3. **AdBannerView**
   - `loadAdIfNeeded` は SDK ready が保証されたときだけ呼ばれる前提にする
   - View 側でバナーを出し分けるので、Container に SDK 知識は持たせない（広告 View は「載ったら load」のまま）
4. **人数正規化**
   - `InputLimits.sanitizedCountText` を `1...999` にクランプ。空・非数字・0 → `"1"`
   - `CountStepper` の `Int(text) ?? 1` は残してよいが、空が来ないことが Presnter 経由では保証される
   - `AttendeeGroupDraft.toDomain()` の `?? 0` はドメイン防御として残す
5. **シェアボタン**
   - `ShareResultButton` は `disabled(!isEnabled)` を使う。必要なら `opacity` で無効見た目を足す
   - `allowsHitTesting` だけに依存しない
6. **シェア文の ViewState 化（計算回数を増やさない）**
   - `applyCalculation` 内で `state.shareText = ShareTextBuilder.build(...)`
   - Presenter の `shareText()` は削除するか、`viewState.shareText` を返す薄ラッパにして View からは呼ばない
   - View は `presenter.viewState.shareText` を渡す

完了条件:

- App の `body` 再評価で Presenter が再生成されない
- 起動パスで「start 完了前の load」がコード上ありえない
- 人数欄を消しても計算人数は 1、ステッパー＋で 2 になる
- エラー時シェアが通常タップでも VoiceOver でも発火しない
- 1 Intent = 1 計算が維持され、シェア文更新のために計算が増えない

### フェーズ 2: 契約を実装と一致させる

目的: README と Contract が「書いてあるだけ」でなく、コンパイル上の依存になる。

実施内容:

1. `SakuttoSplitPresentable` を `SakuttoSplitPresenterProtocol` にリネーム。`shareText()` をプロトコルから削除
2. `SakuttoSplitView` を `SakuttoSplitView<Presenter: SakuttoSplitPresenterProtocol>` にする。`@ObservedObject var presenter: Presenter`
3. `SakuttoSplitRouterProtocol` を削除。Contract から Router 用 `import SwiftUI` が不要になるはず（確認して落とす）
4. Contract の不要 `import Combine` は、`ObservableObject` が Combine 由来なら Presenter 側 import で足りるか確認し、Contract が SwiftUI 非依存になることを優先
5. `CalculationResultSection` は `isShareEnabled` をやめ、`validationIssue == nil` から導出
6. Router テストを Module DTO 前提に更新。ジェネリック View でも `assemble` 後の presenter 状態を検証できること

Binding とクロージャの混在について:

- 総額・端数の `Binding` アダプタ（get = viewState、set = Intent）は **残す**。SwiftUI コントロールが Binding を要求するため
- グループ行のクロージャも **残す**。リストで Binding を Presenter に直接はわせると identity が崩れやすい
- 「3 パターン」のうち解消するのはシェア文メソッドだけ。残り 2 つは意図した使い分けとして README に 1 行書く

完了条件:

- View ファイルに `SakuttoSplitPresenter` 具象名が出ない（ジェネリック制約のみ）
- Contract に未使用プロトコルがない
- App / Router テストが新しい組み立てに追随してグリーン

### フェーズ 3: Draft から Bool モードを除去

目的: `PaymentMode` を唯一の正本にする。

実施内容:

1. `AttendeeGroupDraft.isFixed` 計算プロパティを削除
2. `init` の `isFixed: Bool` を `mode: PaymentMode` に変更
3. 呼び出し側（`SakuttoSplitViewState.initial`、Presenter の新規グループ、Preview、テスト）を置換
4. Entity テストを `mode:` 前提に更新

完了条件:

- リポジトリ全体で `isFixed` が 0 件
- 初期グループ（部長 = 固定、一般 = 割合）の計算結果が変わらない

### フェーズ 4: 一貫性の仕上げ（見た目・識別子・文言置き場）

目的: 継ぎ接ぎ感を消し、診断の軽微項目を閉じる。計算結果とレイアウト数値は変えない。

実施内容:

1. `SplitValidationIssue` → `SakuttoSplitValidationIssue`
2. `RoundingUnit.displayName` を Entity から削除。Picker は View で `"\(unit.rawValue)" + 円キー` 等に組む。円の重複表示に注意
3. 新規グループ名 `"新規グループ\(n)"` をローカライズキー化（例: `group.new_name %lld`）。デフォルト言語の文言は現行どおり
4. `ShareTextBuilder` の日本語は **このフェーズでは維持してよい**。シェア文は外部アプリへ渡すコピーであり、キー化は別途プロダクト判断。計画上は P3 扱いとし、必須完了条件にしない
5. `Localizable.xcstrings` の空キー `""` を削除
6. Xcode プロジェクトの旧称
   - テスト `PRODUCT_BUNDLE_IDENTIFIER`: `com.wkwk.LetsSplitTheBillTests` → アプリ ID に揃えたテスト ID（例: `io.github.mw-wakkun.SakuttoSplitTests`）
   - `remoteInfo = LetsSplitTheBill` を `SakuttoSplit` へ
   - ターゲットの `productName` が `LetsSplitTheBill*` のままなら現行ターゲット名に合わせる
   - **アプリ本体の Bundle ID は変更しない**
7. README
   - View はプロトコルジェネリック
   - App が `@StateObject` で Presenter を所有
   - Router は Module を返す
   - シェア文は ViewState
   - 人数は 1...999（空なし）
8. `refactor_splitView.md` は履歴として残す。本ファイルの実施記録にフェーズ完了を追記する

完了条件:

- 空 xcstrings キーがない
- `isFixed` がない（フェーズ 3 済み）
- README が所有権・契約・人数仕様と一致
- テストバンドル ID に `LetsSplitTheBill` が残っていない（アプリ ID は除く）

---

## 5. ファイル別対応マップ

| 現状 | 移す先 / 変更 | フェーズ |
| --- | --- | --- |
| `SakuttoSplitApp` の `@State splitView` | `@StateObject presenter` + 具象 View 生成。広告 ready フラグ | 1 |
| `SakuttoSplitRouter.assembleModule() -> SakuttoSplitView` | `SakuttoSplitModule` を返す `enum`。Ad プロトコル注入 | 1 |
| `presenter.shareText()` を View `body` で呼び出し | `viewState.shareText`。生成は `applyCalculation` | 1 |
| `InputLimits.sanitizedCountText` が 0 と空を許可 | 1...999。空・0・非数字は `"1"` | 1 |
| `CountStepper` 空欄時 `?? 1` と domain `?? 0` の食い違い | UI 正規化で空を撲滅。domain の `?? 0` は残す | 1 |
| `ShareResultButton.allowsHitTesting` | `.disabled` | 1 |
| `AdBannerView` の即 load | App が start 完了までバナーを載せるのを遅らせる | 1 |
| `SakuttoSplitView` の具象 Presenter | ジェネリック `<Presenter: SakuttoSplitPresenterProtocol>` | 2 |
| `SakuttoSplitPresentable` | リネーム + `shareText()` 削除 | 2 |
| `SakuttoSplitRouterProtocol` | 削除 | 2 |
| `CalculationResultSection` の `isShareEnabled` 引数 | 削除。issue から導出 | 2 |
| `AttendeeGroupDraft.isFixed` | 削除。`mode: PaymentMode` | 3 |
| `SplitValidationIssue` | `SakuttoSplitValidationIssue` | 4 |
| `RoundingUnit.displayName` | View（Picker）へ | 4 |
| Presenter の `"新規グループ"` | xcstrings | 4 |
| xcstrings `""` | 削除 | 4 |
| pbx `LetsSplitTheBill*`（テスト / remoteInfo） | `SakuttoSplit*`。アプリ Bundle ID は不変 | 4 |
| README の所有・契約説明 | 本計画後の実構造 | 4 |

触らないもの:

- Interactor の計算式と端数アルゴリズム
- デフォルトグループ（部長 10000 / 一般 1.0）の金額・人数
- 本番広告ユニット ID と `GADApplicationIdentifier`
- `ShareResultButton` を `.equatable()` で包むこと（`listRowBackground` が落ちる既知理由）

---

## 6. テスト計画

| 対象 | フェーズ | 内容 |
| --- | --- | --- |
| InputLimits | 0–1 | 人数 `""` `"0"` `"abc"` `"1000"` `"12a3"` → `"1"` / `"1"` / `"1"` / `"999"` / `"123"` |
| Presenter | 0–1 | 人数正規化、1 Intent = 1 計算維持、`viewState.shareText` が入力と同時更新 |
| Presenter | 1 | `shareText()` メソッドを View 契約から外したあと、文面は ViewState で既存期待値と一致 |
| Router | 1–2 | Module が presenter と adUnitID を持つ。Ad モックを渡すと ID が差し替わる |
| App 相当 | 1 | 組み立てを `body` で繰り返しても同一 presenter になることは、Router/App の所有テストかコードレビューで担保。UI テスト必須ではない |
| Draft | 3 | `mode:` 初期化。`isFixed` テストを削除 |
| Interactor | 全期間 | 既存ケースを壊さない。人数 0 はドメイン直呼びとして残す |
| シェア無効 | 1 | バリデーション中 `isShareEnabled == false` は既存。ボタン側は Preview / 目視で VoiceOver 非活性を確認 |

計算カウンタ（既存 `CalculatingSpyInteractor`）をフェーズ 1 でも使い、シェア文の ViewState 化で計算が増えていないことを固定する。

---

## 7. リスクと移行方針

| リスク | 対策 |
| --- | --- |
| `@StateObject` を App の `body` で生成してしまう | プロパティ初期化または `init` のみ。レビューで `assembleModule()` の出現箇所を grep |
| ジェネリック View で Preview / Router テストが壊れる | 具象 `SakuttoSplitPresenter` を渡す。型推論できることを完了条件にする |
| 人数 0 → 1 でデフォルト画面の計算が変わる | デフォルト countText はすでに `"1"` / `"4"`。空欄操作以外の期待値は不変のはず。回帰は Presenter 既存テスト |
| 広告プレースホルダでレイアウトが跳ぶ | 未 ready でも高さ 50 を確保。`AdBannerView.equatable()` は維持 |
| SDK start 失敗時にバナー永久非表示 | start の結果にかかわらず ready 扱いにするか、失敗時もプレースホルダ維持。リトライは本計画の範囲外（ログだけでも可） |
| テスト Bundle ID 変更でローカル Scheme が切れる | 共有 Scheme の Test Host はパス指定のままか確認。署名は Automatic |
| 巨大 PR | フェーズごとに PR。0 はテストのみ、1 は寿命と仕様、2 はリネームとジェネリック、3 は Draft、4 は仕上げ |
| 計算結果の期待値と構造変更が混ざる | 人数仕様以外の期待値を変えるコミットを混ぜない |

ブランチ戦略（推奨）:

1. `fix/viper-health-tests`（フェーズ 0）
2. `fix/viper-ownership-ads-count`（フェーズ 1）
3. `fix/viper-contracts`（フェーズ 2）
4. `fix/viper-draft-mode`（フェーズ 3）
5. `fix/viper-consistency`（フェーズ 4）

---

## 8. 優先度

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | フェーズ 0 のテスト | 人数仕様と Module 戻り値を安全に変えるため |
| P0 | Presenter を `@StateObject` 所有 | 状態ロストの根本 |
| P0 | 広告 start → load の順序 | 起動時障害の種 |
| P0 | 人数 1...999 に統一 | 精算額の食い違い |
| P1 | シェア文を ViewState へ | 契約（単一 Published）との一致。計算増なし |
| P1 | シェア `.disabled` | 誤送信 |
| P1 | View ジェネリック + 未使用プロトコル整理 | 契約の嘘をなくす |
| P2 | `isFixed` 削除 | モード正本の一本化 |
| P3 | Validation リネーム、displayName 移動、空キー、旧プロジェクト名、README | 仕上げ。動作非依存 |

---

## 9. 完了の定義

本計画の完了とは、次をすべて満たす状態を指す。

1. Presenter の持ち主が `@StateObject` として App（組み立て結果）にあり、View は観察だけである。View を `@State` に入れない
2. `MobileAds.shared.start()` 完了前に `BannerView.load` が走らない
3. UI 上の人数は常に 1...999。空欄と 0 人入力は正規化される
4. 画面が表示する値はすべて `viewState` から来る。`shareText()` を View が呼ばない
5. View は `SakuttoSplitPresenterProtocol` に依存し、Contract に未使用プロトコルがない
6. `isFixed` がコードベースから消えている
7. フェーズ 0 で固定した計算期待値（人数仕様変更分を除く）がグリーン
8. README の所有権・契約・人数の説明が実装と一致している

---

## 10. 次のアクション

実装開始時は、このファイルのフェーズ単位で PR を切り、完了したフェーズにチェックを付ける。

最初の実装コミットはフェーズ 0（テストのみ）とする。プロダクトコードはフェーズ 1 から。

---

## 11. 実施記録

### フェーズ 0（安全網）

- InputLimits / Presenter に人数の新仕様（空・0・非数字 → `"1"`、同一正規化値は再計算しない）をテストとして先に書いた
- Presenter に `viewState.shareText` が総額変更と同時更新されるテストを追加。文面期待値は現行日本語のまま
- Router に「presenter と空でない bannerAdUnitID」を返す契約のテストを追加（戻り値の型変更はフェーズ 1）
- Interactor テストは未変更
- `SakuttoSplitViewState.shareText` はテストが新 API を参照できるよう空文字のプレースホルダのみ追加。生成の配線はフェーズ 1

### フェーズ 1（寿命・広告・人数・シェア無効化）

- Router を `enum` にし、`assembleModule` は `SakuttoSplitModule`（presenter + bannerAdUnitID）を返す。`AdConfigurationProviding` をデフォルト付きで注入
- App は `@State` の View 所有をやめ、`init` で `assembleModule()` し Presenter を `@StateObject` で所有。`body` では組み立てない
- `MobileAds.shared.start()` 完了後にだけ `AdBannerView` を載せる。未 ready 時は高さ 50 のプレースホルダを残す。Container に SDK 状態は持たせない
- `InputLimits.sanitizedCountText` を 1...999 にクランプ（空・非数字・0 → `"1"`）。Draft の `?? 0` はドメイン防御として残置
- シェア文は `applyCalculation` 内で `viewState.shareText` に代入。View はメソッドではなく ViewState を渡す。`shareText()` は薄ラッパとして残し、契約削除はフェーズ 2
- `ShareResultButton` は `.disabled`（＋無効時 opacity）。`allowsHitTesting` だけには依存しない
- Router テストを Module DTO / Ad 注入前提に更新。シェア文更新で計算が増えないことを Presenter の spy で固定
