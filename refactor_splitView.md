# SakuttoSplitView リファクタリング計画書

- 対象: `SakuttoSplit/Modules/SakuttoSplit/View/SakuttoSplitView.swift` および関連 VIPER モジュール
- 作成日: 2026-09-14
- 方針: **コード実装は行わない**。本ドキュメントは現状分析と段階的な改修計画のみを示す
- 評価観点: VIPER の徹底 / 再利用性 / パフォーマンス / 継ぎ接ぎ実装による一貫性の回復

---

## 1. 現状サマリ

現状は「フォルダ名が VIPER」であり、**責務分離とテスト容易性を担保する VIPER にはなっていない**。

| 層 | ファイル | 実態 |
| --- | --- | --- |
| View | `SakuttoSplitView.swift` | UI + 入力制限 + シェア文生成 + 広告ID切替を抱えるファット View |
| Interactor | `SakuttoSplitInteractor.swift` | 計算ロジックは独立しているが、UI文字列とタプル戻り値に依存 |
| Presenter | `SakuttoSplitPresenter.swift` | ViewModel 兼 Presenter。`calculate()` を View / `didSet` / ミューテーションから多重呼び出し |
| Entity | `AttendeeGroup.swift` のみ | ドメイン値と入力用文字列が混在。計算結果 Entity が不在 |
| Router | `SakuttoSplitRouter.swift` | 組み立て Factory のみ。画面遷移・共有の責務なし |

プロトコル定義はリポジトリ全体で **0件**。Presenter / Interactor / Router は具象型同士で直結している。

単画面アプリとしては動くが、複数 AI による継ぎ接ぎの痕跡（コメントトーン、命名、責務の置き場所、計算トリガーの二重化）がそのまま負債になっている。

---

## 2. 問題点の詳細

### 2.1 VIPER が徹底されていない

#### プロトコルと依存の向き

- View が `SakuttoSplitPresenter` 具象型に依存している（`@ObservedObject var presenter`）。
- Presenter が `SakuttoSplitInteractor` 具象型に依存している。
- Interactor のネスト型 `SakuttoSplitInteractor.CalculationResult` を Presenter が `@Published` で公開し、View まで漏洩している。
- Router は `static func assembleModule() -> AnyView` のみ。VIPER の Router が担うべき「画面遷移・外部連携の起点」がない。
- モック差し替えができないため、Presenter / Router の単体テストが事実上書けない。

#### 責務の侵食

| 置き場所が誤っている処理 | 現状 | 本来の層 |
| --- | --- | --- |
| 総額 8 桁制限 | View の `onChange` | Presenter（入力意図の正規化） |
| `generateShareText()` | View | Presenter（表示用テキスト生成）または専用 Formatter |
| 端数単位 `[1, 10, 100, 500, 1000]` | View にベタ書き | Entity（`RoundingUnit`） |
| 広告ユニット ID の DEBUG/本番切替 | View | 設定（Config）+ Router/組み立て |
| `calculate()` の起動 | View の各 `onChange` / ステッパー / Presenter の `didSet` | Presenter 内部のみ |
| UI 文字列 (`totalAmountText`) を計算に渡す | Interactor 引数 | Presenter が数値化して Entity を渡す |
| 計算結果のタプル | Interactor 戻り値 | Entity（`BillCalculationOutput`） |

#### SwiftUI 向け VIPER とのズレ

UIKit の「ViewProtocol に Presenter が命令する」形を無理に移植する必要はない。一方で、現状は次の点で SwiftUI 版 VIPER としても中途半端である。

- Presenter が `import SwiftUI` している（UI 非依存であるべき）。`Combine` は import されているが未使用。
- Router が `AnyView` で型を消している。組み立て時の型安全性と SwiftUI の structural identity を捨てている。
- `SakuttoSplitApp` の `body` が毎回 `assembleModule()` を呼ぶ。`body` 再評価時に Presenter ごと再生成され、入力状態が消えるリスクがある。
- View が `@ObservedObject` で Presenter を保持しているが、所有権が Router の戻り値側にない。ライフサイクルの正本が不明確。

#### Entity 設計の歪み

`AttendeeGroup` がドメインモデルとフォーム入力 DTO を兼務している。

```swift
var countText: String
var fixedAmountText: String
var ratioText: String
var count: Int { Int(countText) ?? 0 }
```

- Interactor は「人数・金額・倍率」というドメイン値で計算すべきなのに、文字列経由の計算プロパティに依存している。
- 変換失敗時のデフォルトが箇所により違う（View のステッパーは `?? 1`、Entity は `?? 0`）。
- `isFixed: Bool` は「割合 / 固定額」というモードを表しているが、意味が読み取れない。セグメントのタグが `false/true` になっており、UI 都合が Entity に染み出している。
- `let id = UUID()` はメンバワイズ初期化で ID を固定しにくく、永続化・テストの再現性を下げる。
- 計算結果に ID がなく、View 側 `ForEach(..., id: \.name)` に依存している。同名グループで identity 衝突が起きる。

### 2.2 再利用性の低さ

`SakuttoSplitView` は 1 ファイルに画面全体が閉じている。行数自体は過大ではないが、**切り出せる単位がすべてインライン**である。

- グループ行（名前 / 人数ステッパー / 削除 / モード切替 / 詳細入力）が View の `private extension` にベタ書き。
- カスタム人数ステッパーは汎用コンポーネントにできるのに、計算呼び出しまで内包している。
- シェア文、端数単位、広告バナー設定、数値入力制限がすべて画面固有実装。
- 日本語文言がハードコード。将来の設定画面・履歴画面・ウィジェット展開時にコピーが散らばる。
- Interactor が「この画面の TextField 文字列」を知っているため、計算ロジックを他モジュール（履歴再計算、シェア拡張、ウィジェット）から呼べない。
- `View+Extension.hideKeyboard()` は UIKit グローバル依存。テストしづらく、キーボード閉じは画面側の関心として再利用しにくい。
- `AdBannerView` は `connectedScenes.first` / `windows.first` で root VC を探しており、画面が増えた瞬間に誤った VC を掴む。再利用前提のコンポーネントになっていない。

### 2.3 パフォーマンス / 更新効率

計算自体は O(グループ数) で軽く、現時点のボトルネックは **計算回数と SwiftUI 再描画回数** である。

#### 再計算の多重発火

1 回のユーザー操作で `calculate()` が複数回走りうる。

| 操作 | 発火経路 |
| --- | --- |
| 総額入力 | `totalAmountText.didSet` → `calculate()`。8 桁超え時は View が再代入し、`didSet` が再実行 |
| 端数単位変更 | `selectedRoundingUnit.didSet` → `calculate()` |
| グループ名 / モード / 金額 / 倍率 | 各 `onChange` → `calculate()` |
| 人数 +/- | ボタン内で `calculate()` + `countText` の `onChange` でも `calculate()`（二重） |
| 追加 / 削除 | 配列更新後に明示的 `calculate()` |

`groups` 自体は `didSet` を持たないが、`Binding` 経由の更新で `@Published` が発火し、その直後に結果用 `@Published` がさらに更新される。

#### 1 回の計算で View が複数回無効化される

```swift
self.calculationResults = result.results
self.collectedTotal = result.collectedTotal
self.difference = result.difference
```

`ObservableObject` はプロパティごとに `objectWillChange` を送る。キー入力のたびに最大 3 回 + `groups` 変更分の再描画が起きる。

加えて `collectedTotal` は View から参照されていない。無駄な Published である。

#### SwiftUI の identity / 型消去

- `assembleModule() -> AnyView` は差分計算を無効化し、子の再生成を招きやすい。
- 計算結果リストが `id: \.name`。名前変更のたびに行 identity が変わり、セルが作り直される。
- 広告バナーが `body` の兄弟 View として並んでいる（明示的な `VStack` なしの `TupleView`）。Form 側の再描画と並置され、バナー再生成 → 広告再ロードの温床になる。
- `AdBannerView.updateUIView` が空で、`makeUIView` 内で毎回 `load` する。親の再生成に弱い。

#### その他

- 入力のたびに即計算しており、デバウンスがない。現状の件数では実害は小さいが、バリデーションや永続化を足すとキー入力が重くなる。
- Presenter に `@MainActor` がない。Swift 6 の並行性チェックが有効なとき、`@Published` 更新がメインスレッド制約に抵触しうる。
- `ForEach($presenter.groups)` で行全体が 1 つの大きな `VStack`。人数やモードだけ変わっても行全体が再評価される。

### 2.4 一貫性・品質上の負債

複数 AI 実装特有の「同じことを違う場所で違うルールでやる」状態。

- コメント粒度が混在（丁寧なドキュメントコメント / 「計算職人」「魔法のキーワード」などのチュートリアル口調）。
- 型宣言のゆれ: Router は `class`、他は `final class`。
- テストクラス名は `SplitBillInteractorTests`、ファイル名は `SakuttoSplitTests.swift`。
- テストは Interactor のハッピーパス 2 件のみ。空文字、全固定、倍率合計 0、同名グループ、上限桁、単位 1/500/1000 が未カバー。
- 入力サニタイズが総額にしかない。人数・固定額・倍率は不正値を許す。
- 固定額合計が総額を超えた場合、Interactor は残金を 0 にするだけ。View にエラー状態がない。
- `foregroundColor` など、現行 SwiftUI では `foregroundStyle` が推奨される API が残っている。
- 広告初期化が App の `.task`、バナー生成が View、ID 切替が `#if DEBUG` と 3 箇所に分散。
- README は「VIPER でスケーラビリティとテスト容易性を確保」と書いているが、実装がそれに追いついていない。

---

## 3. 目指す姿

SwiftUI に無理な UIKit VIPER を移植せず、**「View は描画と意図の転送だけ、判断は Presenter、計算は Interactor、生成物は Entity、遷移は Router」** を徹底する。

```
┌─────────────────────────────────────────────┐
│ App                                         │
│  @StateObject 相当の Module 所有            │
└──────────────────┬──────────────────────────┘
                   │ assemble
                   ▼
┌──────────────┐  intents   ┌──────────────────────────┐
│ View         │ ─────────► │ Presenter (@MainActor)   │
│ (SwiftUI)    │ ◄───────── │ ViewState を 1 つの       │
│ 描画のみ     │  viewState │ Published で公開          │
└──────────────┘            └────────────┬─────────────┘
                                         │ Entity
                                         ▼
                            ┌──────────────────────────┐
                            │ Interactor (protocol)    │
                            │ 純粋関数的な計算         │
                            └──────────────────────────┘
                                         │
                            ┌────────────┴─────────────┐
                            │ Entity                   │
                            │ RoundingUnit             │
                            │ PaymentMode              │
                            │ AttendeeGroup            │
                            │ BillCalculationInput     │
                            │ BillCalculationOutput    │
                            └──────────────────────────┘

Router: 組み立て / 共有シート / 将来の設定・履歴遷移
Config: 広告 ID、入力上限、デフォルトグループ
```

### 3.1 各層の契約（導入するプロトコル）

```swift
@MainActor
protocol SakuttoSplitPresentable: ObservableObject {
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
    func shareText() -> String
}

protocol SakuttoSplitInteractorProtocol {
    func calculateBill(_ input: BillCalculationInput) -> BillCalculationOutput
}

@MainActor
protocol SakuttoSplitRouterProtocol {
    static func assembleModule() -> SakuttoSplitView
    // 将来: func routeToSettings()
}

protocol AdConfigurationProviding {
    var bannerAdUnitID: String { get }
}
```

View 側に `SakuttoSplitViewProtocol` は置かない。SwiftUI では View が struct のため、UIKit 的な View プロトコルは形式だけになりやすい。テストは Presenter / Interactor をプロトコル経由で行う。

### 3.2 Entity の分離

| Entity | 役割 |
| --- | --- |
| `PaymentMode` | `.ratio` / `.fixed`。Bool を廃止 |
| `RoundingUnit` | `1 / 10 / 100 / 500 / 1000`。表示名と raw value を持つ |
| `AttendeeGroup` | `id`, `name`, `count: Int`, `mode`, `fixedAmount: Int`, `ratio: Decimal` |
| `AttendeeGroupDraft`（Presenter 専用でも可） | TextField 用の文字列。ドメインへ変換する |
| `BillCalculationInput` | 総額 `Int` + 単位 + グループ配列 |
| `GroupCalculationResult` | `groupID`, `name`, `amountPerPerson`, `total` |
| `BillCalculationOutput` | `results`, `collectedTotal`, `difference` |

Interactor は文字列を受け取らない。パース失敗や上限超過は Presenter が ViewState のエラーとして表現する。

### 3.3 ViewState の単一化

```swift
struct SakuttoSplitViewState: Equatable {
    var totalAmountText: String
    var roundingUnit: RoundingUnit
    var groups: [AttendeeGroupDraft]
    var results: [GroupCalculationResult]
    var difference: Int
    var validationMessage: String?
}
```

Presenter は `viewState` だけを `@Published` する。計算のたびに View 無効化は 1 回。

---

## 4. フェーズ別計画

進捗:

- [x] フェーズ 0
- [x] フェーズ 1
- [x] フェーズ 2
- [x] フェーズ 3
- [x] フェーズ 4
- [ ] フェーズ 5

実装はまだ行わない。着手するときは **フェーズ 0 → 1 の順** を崩さない。後工程ほど UI 差分が出る。

### フェーズ 0: 安全網（テストを先に厚くする）

目的: リファクタで計算結果が変わらないことを保証する。

追加すべき Interactor ケース:

- 総額空文字 / 非数値 → 0 として扱う現行仕様を明示
- グループ 0 件
- 全員固定額、総額ちょうどの場合 / 超過する場合
- 倍率グループのみで `totalRatio == 0`（倍率空・0）
- 端数単位 1, 10, 500, 1000
- 人数 0 または不正文字列
- 同名グループが 2 件（結果は ID で区別できること）
- 固定額 × 人数の合算が総額を超える

このフェーズでは **プロダクトコードを変えず**、現行仕様をテストで固定する。仕様がバグなら、フェーズ 1 以降で「仕様変更」として別途扱う。

### フェーズ 1: Entity と Interactor の純化

目的: ビジネスロジックを UI から切り離し、再利用可能な計算コアにする。

実施内容:

1. `PaymentMode`, `RoundingUnit`, `BillCalculationInput`, `BillCalculationOutput`, `GroupCalculationResult` を `Entity/` 配下に追加する。
2. `AttendeeGroup` から `*Text` を除去し、数値ドメインにする。`id` は `init` で注入可能にする（テスト再現性）。
3. Interactor を `SakuttoSplitInteractorProtocol` に適合させる。引数は Input Entity、戻り値は Output Entity。タプルを廃止する。
4. `CalculationResult` の Interactor ネストを廃止する。
5. フェーズ 0 のテストを新シグネチャに追随させる。期待値は変えない。

完了条件:

- Interactor が `Foundation` 以外の UI フレームワークを知らない。
- 計算を View なしで呼べる。
- 既存 2 テスト + 追加テストがすべてグリーン。

### フェーズ 2: Presenter / Router の VIPER 再配置

目的: View から判断・整形・計算起動を取り除く。

実施内容:

1. Presenter を `@MainActor` + `SakuttoSplitPresentable` にする。`import SwiftUI` をやめる。
2. 入力変更 API を Intent メソッドに統一する。View は `presenter.calculate()` を呼ばない。
3. `didSet` と View `onChange` の二重計算を廃止する。正規化（桁数制限、人数 1...999、数値以外の除去）は Intent 内で 1 回だけ行う。
4. `shareText()` を Presenter（または `ShareTextBuilder`）へ移す。View の `generateShareText()` を削除する。
5. `viewState` を単一 `@Published` にする。`calculationResults` / `collectedTotal` / `difference` のバラ Published をやめる。
6. Router を `final` にし、`AnyView` をやめる。戻り値は具象 `SakuttoSplitView`。
7. App 側でモジュールを安定所有する。

```swift
@State private var splitView = SakuttoSplitRouter.assembleModule()
```

または Router が Presenter を保持し、View はそれを受ける。`assembleModule()` を `body` で毎回呼ばない。

8. 広告 ID は `AdConfiguration`（DEBUG/Release）へ移し、Router 組み立て時に View へ渡す。View から `#if DEBUG` を消す。

完了条件:

- View に計算式・シェア文・桁数制限・広告 ID がない。
- Presenter をモック Interactor でテストできる（追加 / 削除 / 入力正規化 / シェア文）。
- Router が型消去しない。

### フェーズ 3: View 分割と再利用コンポーネント化

目的: `SakuttoSplitView` を「セクションの組み立て」だけにする。

推奨分割:

```
View/
  SakuttoSplitView.swift          // Form の骨格のみ
  Subviews/
    TotalAmountSection.swift
    GroupListSection.swift
    GroupRowView.swift
    RoundingUnitPicker.swift
    CalculationResultSection.swift
    DifferenceRow.swift
    ShareResultButton.swift
Components/
  BoundedIntegerField.swift       // 桁数・数字のみ
  CountStepper.swift              // 1...999 の汎用ステッパー
  AdBannerView.swift              // root VC 解決を改善
```

実装ルール:

- サブビューは Presenter 全体を受け取らない。必要な Binding / 値 / クロージャだけを受ける。
- `CountStepper` は「値を変える」だけ。計算は呼ばない。
- グループ行の identity は `group.id`。結果行も `groupID`。
- 広告バナーは Form の外で `VStack(spacing: 0)` に明示配置し、`safeAreaBar` または固定フレームで切り離す。
- `hideKeyboard()` は画面の toolbar に閉じるか、`@FocusState` に置換する。UIApplication 直叩きをやめる。
- 文言は段階的に `LocalizedStringKey` / String Catalog へ移す（このフェーズでキー化、値は現行日本語のまま）。

完了条件:

- `SakuttoSplitView.body` がセクション列挙程度まで薄い。
- 人数ステッパーと数値フィールドが他画面から使える。
- Preview が各サブビュー単位で成立する（Presenter なし、またはスタブ）。

### フェーズ 4: パフォーマンス

目的: キー入力 1 回 = 計算 1 回 = View 無効化 1 回。広告は再ロードしない。

実施内容:

1. 計算トリガーを Presenter 内部の 1 箇所に集約する（フェーズ 2 で実施済みなら検証のみ）。
2. 出力を `viewState` 1 本にする（同上）。
3. グループ行を `Equatable` な子 View にし、変わった行だけ再描画されるようにする。
4. 計算結果セクションは `results` と `difference` だけを受け、入力中の TextField と切り離す。
5. 広告バナーは `equatable()` または ID 固定の独立 View にし、Form 更新で `makeUIView` が走らないことを確認する。`rootViewController` は `UIView` の `window` から取る。
6. 将来、永続化や重い整形を足す場合のみ、入力デバウンス（150–250ms）を入れる。現状の純計算だけなら必須ではない。
7. `ForEach(id: \.name)` を全廃する。

完了条件:

- Instruments の SwiftUI または単純な計算カウンタで、人数 +/- が 1 操作 1 計算になる。
- 総額入力中に広告リクエストが増えない。
- 同名グループを 2 つ作っても結果リストが壊れない。

### フェーズ 5: 一貫性・品質の仕上げ

目的: 継ぎ接ぎ感を消し、README の宣言と実装を一致させる。

- ファイルヘッダ / ドキュメントコメントのトーンを統一する（チュートリアル口調を削除）。
- `final` / アクセス制御 (`private`, `package` or `internal`) を揃える。
- テストファイル名とクラス名を対応させる。Presenter テストを追加する。
- 非推奨 API（`foregroundColor` 等）を現行 API に置換する。
- エラー状態（総額未入力、固定額超過、グループ 0 件）を ViewState で表現し、シェアボタンの disabled を決める。
- README のアーキテクチャ節を、本計画後の実構造に更新する（実装完了後）。

---

## 5. 目標ファイル構成

```
SakuttoSplit/
  App/
    SakuttoSplitApp.swift
  Config/
    AdConfiguration.swift
    InputLimits.swift                 // 総額 8 桁、人数 1...999 など
  Entity/
    AttendeeGroup.swift
    PaymentMode.swift
    RoundingUnit.swift
    BillCalculation.swift             // Input / Output / GroupCalculationResult
  Modules/
    SakuttoSplit/
      Contract/
        SakuttoSplitContract.swift    // プロトコルを 1 箇所に集約
      View/
        SakuttoSplitView.swift
        Subviews/...
      Presenter/
        SakuttoSplitPresenter.swift
        SakuttoSplitViewState.swift
        ShareTextBuilder.swift        // 不要なら Presenter 内で可
      Interactor/
        SakuttoSplitInteractor.swift
      Router/
        SakuttoSplitRouter.swift
  Components/
    CountStepper.swift
    BoundedIntegerField.swift
    AdBannerView.swift
  Extensions/
    （hideKeyboard は廃止予定。残すなら UIKit 依存を限定）
```

Contract を 1 ファイルにまとめる理由: 小規模モジュールではプロトコルがファイル数だけ増えると、かえって継ぎ接ぎ感が出る。大きくなった時点で分割する。

---

## 6. 主要な設計判断

### 6.1 採用する

| 判断 | 理由 |
| --- | --- |
| SwiftUI + VIPER は Intent / ViewState 方式 | ViewProtocol 命令型は struct View と相性が悪い |
| Interactor は同期の純関数 | 割り勘計算に非同期は不要。テストが単純 |
| 入力文字列は Presenter（Draft）に残す | TextField は String が必要。ドメインを汚さない |
| 計算結果に `groupID` を持たせる | 同名グループと安定 identity のため |
| 広告は Router/Config から注入 | View のコンパイル条件を減らす |
| シェアは当面 `ShareLink` のまま | UIKit UIActivity へ無理に移さない。文面生成だけ Presenter へ |

### 6.2 採用しない（過剰）

| 判断 | 理由 |
| --- | --- |
| Rx / Combine パイプラインでの計算 | 入力数が少なく、Intent メソッドで足りる |
| Interactor の async | I/O がない |
| 本格 DI コンテナ | モジュール 1 つの手動組み立てで足りる |
| View プロトコル + AnyView ホスト | 型消去とボイラープレートが増えるだけ |
| 今すぐの多言語ファイル完備 | リファクタ本体を遅らせる。キー化までがフェーズ 3 |
| 入力デバウンス必須化 | 現行計算量では効果より複雑性が勝る |

### 6.3 仕様として確認が必要な点（実装時に決める）

リファクタ中に「バグ修正」と「仕様変更」を混ぜないこと。下記は現行踏襲がデフォルト。

- 総額の非数値が `0` になること
- 端数は常に切り捨て
- 固定額合計が総額超過時、按分は 0、不足金表示のみ
- グループ削除で 0 件になっても計算は継続
- デフォルトグループ（部長 10000 / 一般 1.0 倍）

仕様を変える場合は、フェーズ 0 のテストを先に書き換えてからプロダクトを変える。

---

## 7. テスト計画

| 対象 | フェーズ | 内容 |
| --- | --- | --- |
| Interactor | 0–1 | 現行仕様の固定 + 境界値 |
| Entity 変換 | 1–2 | Draft → Domain のパース、不正値、桁クリップ |
| Presenter | 2 | 追加削除、正規化、二重計算しないこと、シェア文、ViewState 一括更新 |
| Router | 2 | 組み立て後の View が Presenter を保持すること（スナップショット不要、型で十分） |
| View | 3 以降 | 必須ではない。行うなら `ViewInspector` 等は導入コストを見て判断。まずは Preview で目視 |

計算カウンタ（テスト用 Interactor スパイ）で「1 Intent = 1 calculate」を Presenter テストに入れると、フェーズ 4 の退行を防げる。

---

## 8. リスクと移行方針

| リスク | 対策 |
| --- | --- |
| 巨大 PR になりレビュー不能 | フェーズごとに PR を分ける。0 → 1 はテストと Entity のみ |
| 見た目が微妙に変わる | フェーズ 3 までレイアウト数値を変えない。コンポーネント切り出しは移動のみ |
| Binding を Intent に変えて入力カーソルが飛ぶ | 総額・人数などは「正規化は editing end、または同一文字列なら state を更新しない」 |
| `id = UUID()` 変更で SwiftUI が行を再生成 | 既存インスタンスの ID を移行時に保持。デフォルトグループは固定 UUID をテストで使う |
| 広告が一時的に消える / 再ロード | バナーを Form から分離して最後に動かす |
| README / 計画書と実装が再乖離 | フェーズ 5 で README を更新。本ファイルの「実施記録」を追記する |

ブランチ戦略（推奨）:

1. `refactor/split-tests`（フェーズ 0）
2. `refactor/split-entity-interactor`（フェーズ 1）
3. `refactor/split-presenter-router`（フェーズ 2）
4. `refactor/split-view-components`（フェーズ 3）
5. `refactor/split-perf-consistency`（フェーズ 4–5）

各 PR は前のマージ後に始める。計算結果の期待値を変えるコミットと、構造変更のコミットを混ぜない。

---

## 9. 優先度

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | フェーズ 0 のテスト拡充 | これがないと以降が安全に進められない |
| P0 | Interactor の Entity 化とプロトコル化 | VIPER の心臓。再利用の前提 |
| P0 | `calculate()` の単一入口化 | 正しさとパフォーマンスの両方に効く |
| P1 | シェア文 / 桁制限 / 端数単位を View から除去 | View の負債の本体 |
| P1 | `AnyView` 廃止と Presenter 所有権の固定 | 状態ロストと不要再生成の防止 |
| P1 | 結果リストを `groupID` で識別 | 実害のあるバグ |
| P2 | View コンポーネント分割 | 可読性・再利用。機能差は出さない |
| P2 | ViewState 単一 Published | 再描画回数 |
| P2 | 広告 Config 分離とバナー安定化 | 再ロード防止 |
| P3 | 文言キー化、API 近代化、README 同期 | 仕上げ |
| P3 | デバウンス | 将来の重い処理用。今は不要 |

---

## 10. 現状コードへの具体的な対応マップ

実装時のチェックリスト。この表の「移す先」以外にロジックを残さない。

| 現状 | 移す先 | フェーズ |
| --- | --- | --- |
| `SakuttoSplitView.totalAmountField` の 8 桁制限 | `InputLimits` + Presenter Intent | 2 |
| `roundingUnitPicker` の配列リテラル | `RoundingUnit.allCases` | 1–3 |
| `groupsList` / `stepperSection` / `detailInputField` / `deleteButton` | `GroupRowView` + `CountStepper` | 3 |
| `resultsList` の `id: \.name` | `GroupCalculationResult.groupID` | 1–3 |
| `summarySection` | `DifferenceRow`（値だけ受ける） | 3 |
| `generateShareText()` | `ShareTextBuilder` / Presenter | 2 |
| `#if DEBUG` 広告 ID | `AdConfiguration` | 2 |
| `presenter.calculate()` の View からの呼び出し | 削除。Intent 内で完結 | 2 |
| `totalAmountText.didSet` / `selectedRoundingUnit.didSet` | 削除。Intent に統合 | 2 |
| `SakuttoSplitInteractor.CalculationResult` | `GroupCalculationResult` | 1 |
| タプル戻り値 | `BillCalculationOutput` | 1 |
| `assembleModule() -> AnyView` | 具象 View | 2 |
| App からの毎回 assemble | 安定所有 | 2 |
| `View+Extension.hideKeyboard` | `@FocusState` | 3 |
| `AdBannerView` の windows 探索 | banner 自身の window | 4 |
| `SplitBillInteractorTests` 名称 | ファイル名と一致 | 5 |

---

## 11. 完了の定義

リファクタ完了とは、次をすべて満たす状態を指す。

1. View は描画と Intent 転送だけを行う。
2. Interactor は Entity だけを入出力し、プロトコル経由で差し替えできる。
3. Presenter は `@MainActor` で ViewState を 1 つ公開し、計算を 1 入口で行う。
4. Router は組み立てと（必要な範囲の）外部遷移だけを行う。`AnyView` を使わない。
5. グループと計算結果の identity が UUID で安定している。
6. フェーズ 0–1 で固定した計算期待値がすべてグリーン。Presenter テストがある。
7. 人数ステッパー操作が 1 回の計算で済む。広告が入力のたびに再ロードされない。
8. README の VIPER 説明が実装と一致している。

---

## 12. 次のアクション

次に着手するのは **フェーズ 5（一貫性・品質の仕上げ）** である。

実装開始時は、このファイルのフェーズ単位で PR を切り、完了したフェーズにチェックを付けること。

---

## 13. 実施記録

### フェーズ 4（パフォーマンス）

- 計算トリガーはフェーズ 2 の `applyUpdate` 1 箇所のまま。Presenter テストで人数 +/- が 1 Intent = 1 計算であることを固定した
- `GroupRowView` / `ResultRow` / `DifferenceRow` / `ShareResultButton` / `AdBannerView` を `Equatable` にし、`.equatable()` で変わった行だけ再評価する
- `CalculationResultSection` は `results` / `difference` / `shareText` の値だけを受け、入力中の TextField とは切り離す。`ShareLink` は `.equatable()` で包まない（Form の `listRowBackground` が落ちるため）
- `AdBannerView` は自身の `window.rootViewController` から root を取り、初回 attach 時だけ `load` する
- `ForEach(id: \.name)` は残っていない。結果の identity は `GroupCalculationResult.groupID`
- 入力デバウンスは未導入（計画どおり、現行の純計算では不要）
