# 安全性・パフォーマンス コードレビュー 修正計画書

- 対象: VIPER モジュール `Modules/SakuttoSplit` と、その依存（`Entity` / `Config` / `Ads` / `Session` / `Components`）
- 作成日: 2026-09-15
- 前提: VIPER 化（`refactor.md`）と v2.0.0〜v2.3.0 スライスは完了済み
- 入力: 同日のシニア iOS コードレビュー（メモリ / クラッシュ / パフォーマンス・Swift 記法）
- 方針: **この文書ではコード実装を行わない**。実装者が迷わないよう、仕様・責務・手順・完了条件だけを固定する
- 評価観点: ユーザー入力と SDK コールバックで trap / SwiftUI クラッシュしない / 循環参照を作らない / 計算期待値（端数切り捨て・固定超過時の按分 0）を変えない / VIPER 境界を壊さない

`MARKETING_VERSION` は上げない。schema / UserDefaults キーは変えない。Store リリース判断は本計画の外。

目的は、割り勘の式や画面階層を変えずに、**落ちる経路と無駄な再計算を潰す**ことである。

---

## 0. なぜこれを次にするか

機能不足ではない。通常の宴会入力では再現しにくいが、次の 3 系統は本番で trap / クラッシュしうる。

| 起きること | 現場 |
| --- | --- |
| 倍率欄に長い数字を貼る | `Double` が `inf` → Interactor の `Int(...)` が trap。キー入力のたびに計算が走る |
| リワード視聴中 | View の `self` が `pendingOnEarned` に入り、`AdsController` と循環。SDK 完了がメインスレッド以外だと `@Published` で SwiftUI が落ちる |
| 破損した lastBill / 編成 JSON | 同 ID グループで `Dictionary(uniqueKeysWithValues:)` と `ForEach` が `fatalError` |

計算・広告ルール・前回会計の保存点は正しい。直すのは防御と寿命と、同じ結果を出すための書き方である。

---

## 1. 現状サマリ

| 項目 | 現状 |
| --- | --- |
| 強制アンラップ | 本番に `!` / `as!` / `try!` はほぼ無い |
| 配列添字 | Presenter / Focus は `firstIndex` 後。通常経路は範囲外にならない |
| 倍率 | `sanitizedRatioText` はドット 1 つのみ。桁上限なし。`parseRatio` は `Double` 経由 |
| 計算 | Interactor が `Int(rawAmount / unit)` と `roundedAmount * count` を無検査 |
| 席金額 | `Dictionary(uniqueKeysWithValues:)`。重複キーで即死 |
| 広告コールバック | `onDidFinish` は `Task`、`onDidEarnReward` は同期。`@MainActor`  hop なし |
| リワード onEarned | View メソッドを捕獲。`AdsController` がクロージャを保持 |
| `refreshAdFreeState` | `Task { await startLoadingIfNeeded() }` が `self` を強参照。186 行は `[weak self]` |
| 復元 / 編成適用 | `applyUpdate` 内 reconcile のあと、paid キー指定でもう一度 reconcile |
| `lastBill` | getter のたびに JSON デコード。`makeSessionChrome` は 2 回読む |
| グループ数 | 追加上限なし |
| 未払いシェア文 | Presenter の計算プロパティ。席トグルのたびに全文再生成 |
| 所有 | App が Presenter / AdsController を `@StateObject`。古典 VIPER 循環は無い |

---

## 2. 設計判断（先に決めること）

実装中にひっくり返さない。

### 2.1 採用する

| 判断 | 理由 |
| --- | --- |
| 倍率は UI で桁を切る。Interactor は有限値チェックで trap しない | 入力正規化とドメイン防御を分ける。人数と同じ型 |
| 計算は現行どおり Double。`Decimal` 化しない | 6200 円などの期待値を維持する。本計画は安全性だけ |
| `parseRatio` は `Double` のまま。`inf` / `nan` は `0` | 変換経路を変えて端数を動かさない |
| SDK コールバックはすべて `Task { @MainActor [weak self] in }` | `@Published` をメイン以外から書かない |
| リワード `onEarned` は Presenter（class）だけ捕獲する | View の `self` を `AdsController` に渡さない |
| 保存名 Alert は chrome のフラグで出す | クロージャから View メソッドを呼ぶ必要を消す |
| グループ ID 重複は Presenter が振り直す | `ForEach` の identity を保証する。Dictionary 側も `uniquingKeysWith` で二重化 |
| 復元・編成・Undo の reconcile は 1 回 | 中間の済フラグを publish しない |
| `makeSessionChrome` は `lastBill` を 1 回だけ読む | Store を class にしない。struct 契約を維持 |
| グループ数上限 `20` | 席展開上限と同じ桁。Form の線形増加を止める |
| 未払いシェア文は collection 更新と同時にキャッシュ | メインシェアが `viewState.shareText` なのに未払いだけ毎 `body` 生成なのを揃える |

### 2.2 採用しない

| 判断 | 理由 |
| --- | --- |
| Interactor の金額計算を `Decimal` に置き換える | 期待値が動く。別計画 |
| `BillSessionStore` を class にしてメモリキャッシュする | 本計画の実害は chrome の二重デコード。型変更は過剰 |
| `pendingOnEarned` をやめて Ads が Presenter を知る | VIPER 境界。Presenter は GoogleMobileAds を import しない |
| 倍率の数値クランプ（例: 0.01...100）を Interactor に入れる | UI 桁制限で `inf` は止まる。ドメインは 0 と有限チェックだけ |
| schema 3 / paidSeatKeys キー変更 | 重複 ID は実行時に振り直す。Disk 形は変えない |
| 入力デバウンス | 現行計算は軽い。人数仕様のときと同じ |
| `MARKETING_VERSION` を上げる | バグ修正。2.0.0 に含める |

### 2.3 絶対ルール

実装者が迷ったら、ここに戻る。

1. 既存 Interactor テストの金額期待値を変えない（人数 0 のドメイン直呼びも含む）
2. 1 Intent = 1 計算。シェア文の項目（総額・1人あたり・過不足・送金依頼）を変えない
3. Presenter は GoogleMobileAds を import しない
4. 席展開規則（20 以下展開、21 以上 1 行）は不変
5. 初期グループ（部長 1 / 10,000、一般 4 / 1.0）は不変
6. 強制アンラップを新しく足さない
7. `Task` で class を捕獲するなら `[weak self]`。View の escaping クロージャは class 参照だけをローカル定数に逃がす

---

## 3. 仕様

### 3.1 倍率の正規化

`InputLimits` に定数を足す。

```swift
static let ratioIntegerMaxDigits = 3
static let ratioFractionMaxDigits = 2
```

`sanitizedRatioText` の完成形:

1. 現行どおり、数字と **最初の 1 つの `.`** だけ残す（`"1.2.5"` → `"1.25"` は維持）
2. `.` より前は最大 3 桁、後は最大 2 桁
3. 空文字と `"."` はそのまま返す（パース結果 0 は現行どおり）

例:

| 入力 | 出力 |
| --- | --- |
| `1.25` | `1.25` |
| `1.2.5` | `1.25` |
| `.` | `.` |
| `1234.567` | `123.56` |
| `9999` | `999` |
| （400 桁の 9） | `999` |

Presenter の `didChangeRatio` は現行どおりこの関数を通す。復元した古い `ratioText` は、ユーザーが編集するまで切り詰めない（lastBill の正本を勝手に書き換えない）。防御は `parseRatio` と Interactor が担う。

`AttendeeGroupDraft.parseRatio`:

```swift
guard let value = Double(text), value.isFinite else { return 0 }
return Decimal(value)
```

`Decimal(string:)` への切り替えは禁止（端数が動きうる）。

### 3.2 Interactor の trap 防止

`calculateBill` の倍率枝（現行 43–54 行付近）:

1. `rawAmount` / `unit` が有限でない、または `unit <= 0` なら、そのグループは `amountPerPerson = 0` / `total = 0`（`totalRatio == 0` 枝と同じ）
2. `Int(...)` する前に、値が `Int` に収まることを確認する。収まらなければ同じく 0
3. `roundedAmount * group.count` はオーバーフローしたら `total = 0`（`amountPerPerson` も 0 に揃える）
4. **有限で範囲内の値は、現行と同一の式** `(Double(remainingAmount) / totalRatio) * ratio` → `Int(rawAmount / unit) * roundingUnit`

走査回数を 1 回にまとめてよい。結果配列の順序・同名グループの分離・固定超過時の按分 0 は維持する。

### 3.3 グループ ID の一意性

`AttendeeGroupDraft.id` は `let` のまま。重複時は **後続だけ新しい UUID で作り直す**。先頭の ID は残す。振り直した席の済キーは幽霊扱い（現行の reconcile と同じく捨てる）。

呼び場所:

- `applyUpdate` の `update` 直後（restore / apply member set / 通常編集を一括でカバー）
- `init` の `initialState` にも同じ関数を通す

重複が無ければ配列は入力と `==`。計算増を起こさない。

`CollectionState.reconcile` の金額 Dictionary は:

```swift
Dictionary(results.map { ($0.groupID, $0.amountPerPerson) }, uniquingKeysWith: { _, last in last })
```

`uniqueKeysWithValues` は削除する。Presenter の uniquify が本命。こちらは二重化。

### 3.4 グループ数上限

```swift
static let groupMaxCount = 20
```

- `didTapAddGroup` は `groups.count >= groupMaxCount` なら no-op（計算しない）
- `GroupListSection` の追加ボタンは上限で `.disabled`
- 復元・編成適用で 20 件超が来たら、**先頭 20 件を残す**（保存済みデータを落とすより、画面を守る）

### 3.5 単一 reconcile

`applyUpdate` に paid キーを足す。

```swift
private func applyUpdate(
    _ update: (inout SakuttoSplitViewState) -> Void,
    paidSeatKeys: Set<String>? = nil
)
```

- `nil`: 現行どおり `collectionState.paidSeatKeys` を引き継ぐ
- `.some`: その集合で 1 回だけ reconcile する
- `applyUpdate` の末尾で `reconcileCollection(paidSeatKeys:)` を **1 回**
- 呼び出し側の二度目の `reconcileCollection` は削除

| Intent | paidSeatKeys |
| --- | --- |
| 通常の入力変更 | `nil` |
| `didTapRestoreLastBill` | `Set(snapshot.paidSeatKeys)` |
| `didTapApplyMemberSet` | `[]` |
| `didTapUndoMemberSetApply` | `[]` |
| `didTapSettleComplete` | `nil`（initial で validation のため空になる） |

`memberSetUndo = nil` は現行どおり `applyUpdate` 内。編成適用は **そのあと** に `memberSetUndo = undo` を入れる順序を崩さない。

### 3.6 広告: メインスレッドと寿命

`AdsController`:

1. `refreshAdFreeState` の `Task` は `{ [weak self] in await self?.startLoadingIfNeeded() }`
2. `loaded?.onDidFinish` / `onDidEarnReward` は `[weak self]` のうえ、本体処理は `Task { @MainActor [weak self] in ... }`
3. `GoogleInterstitialAd` / `GoogleRewardedAd` の delegate メソッドも、`onDidFinish` / `onDidEarnReward` を呼ぶ前にメインアクターへ hop する（SDK 実装のスレッドを信じない）
4. `rewardUnavailableClearTask` の `[weak self]` は維持

View `presentExtraSlotRewarded`:

```swift
let presenter = self.presenter
adsController.presentRewarded(
    from: rootViewController,
    purpose: .extraMemberSetSlot
) {
    presenter.didUnlockMemberSetSlot()
}
```

**禁止:** このクロージャから `presentSaveNamePrompt()` や他の View メソッドを呼ぶこと。`self.` を 1 つでも書くと struct 全体（`AdsController` 含む）が循環する。

保存名 Alert の代替:

`SakuttoSplitSessionChrome` に `needsSaveMemberSetNamePrompt: Bool`（既定 `false`）を足す。

`didUnlockMemberSetSlot` が枠を増やせたとき、`hasEmptyMemberSetSlot` なら `true` にする。View は `.onChange` または Binding で Alert を出し、出した時点で Presenter の `didConsumeSaveMemberSetNamePrompt()`（名前は実装者に任せる。Intent であること）が `false` に戻す。

`didTapHideAdsForToday` の `onEarned` は nil のまま。変えない。

Undo バナー `Task`:

- 既存の「新しいバナーを出す前に cancel」は維持
- `.onDisappear` でも `memberSetUndoBannerHideTask?.cancel()` する

### 3.7 chrome の `lastBill` 読み

`makeSessionChrome`:

```swift
let lastBill = sessionStore.lastBill
return SakuttoSplitSessionChrome(
    hasLastBill: lastBill != nil,
    lastBillPreview: Self.makeLastBillPreview(from: lastBill),
    ...
)
```

`sessionStore.lastBill` を 2 回呼ばない。プレビューの席生成は `CollectionSeat.make` 相当のままでよい（展開規則を二重実装しない）。Store の型は struct のまま。

### 3.8 未払いシェア文のキャッシュ

`unpaidShareText` / `isUnpaidShareEnabled` を席トグルのたびに組み直さない。

Presenter に private な `setCollectionState(_ next: CollectionState)` を置き、`collectionState` 代入と同時に未払い文を更新する。`totalAmountText` が変わる `applyUpdate` 経路も、reconcile 後に同じ関数を通す。

プロトコルの getter は残す。View の渡し方は変えてよいが、CollectionSection が毎 `body` で Presenter 計算プロパティに依存し続ける状態はやめる。

### 3.9 CollectionSection のグループ化とハプティクス

- 出現順を保ったまま `Dictionary(grouping: seats, by: \.id.groupID)` を使う。`grouped[id, default: []].append` の手書きループは削除
- `unpaidCount` / `paidFraction` は `seats` を 2 回 `filter` しない。1 回数える
- `UIImpactFeedbackGenerator(style:)` をタップのたびに `init` しない。画面寿命で再利用する小さな型（static または `@State` の参照型）に閉じ、`prepare()` してから鳴らす

### 3.10 仕上げ（計算結果を変えない書き換え）

- Interactor の groups 3 走査を、固定合計・倍率合計を集める 1 走査 + 結果 `map` にまとめてよい
- `ShareTextBuilder` の `for` + `+=` は `map` + `joined` にしてよい。**出力文字列は既存テストと一致させる**
- `CountStepper` のプラスは `currentCount >= range.upperBound` で `.disabled`。マイナスと対称にする

---

## 4. 診断項目との対応

| 診断 | 重大度 | 本計画での扱い | フェーズ |
| --- | --- | --- | --- |
| `Int(Double)` / `*` の trap | 高 | 有限チェック + オーバーフロー時 0 | 1 |
| 倍率の桁なし | 高 | 整数 3 / 小数 2。`parseRatio` は finite のみ | 1 |
| SDK コールバックから `@Published` | 高 | 全経路 `@MainActor` hop | 2 |
| `onEarned` が View を捕獲 | 高 | Presenter だけ捕獲 + chrome フラグ | 2 |
| `uniqueKeysWithValues` / `ForEach` 重複 ID | 中 | uniquify + `uniquingKeysWith` | 3 |
| `applyUpdate` 後の二重 reconcile | 中 | paid キー引数で 1 回 | 3 |
| `Task` の強参照 self | 中 | `[weak self]` 統一 | 2 |
| Undo バナー Task 未 cancel | 中 | `onDisappear` | 2 |
| `lastBill` 二重デコード | 中 | chrome で 1 回 | 4 |
| グループ追加無制限 | 中 | 上限 20 | 4 |
| 未払い文の毎 `body` 生成 | 低〜中 | キャッシュ | 4 |
| `seatGroups` 手書き / ハプティクス再生成 | 低 | grouping + 再利用 | 4 |
| Interactor 3 ループ / ShareText `+=` / プラス未 disabled | 低 | 同等書き換え | 5 |

---

## 5. フェーズ別計画

実装は **フェーズ 0 → 5 の順**。クラッシュ修正とリネームと見た目変更を 1 PR に混ぜない。

進捗:

- [x] フェーズ 0
- [x] フェーズ 1
- [x] フェーズ 2
- [x] フェーズ 3
- [x] フェーズ 4
- [x] フェーズ 5

### フェーズ 0: 安全網（テストを先に固定）

目的: 仕様を変える箇所だけテストを先に書き、変えない箇所のグリーンを固定する。

実施内容:

1. **変えないこと（既存のままでよい）**
   - Interactor: 基本割り勘、固定+割合の 6200、端数 1/10/500/1000、固定超過時の按分 0、同名グループ、人数 0 のドメイン直呼び
   - シェア文面の日本語と項目順
   - 席展開 20、人数 1...999、総額 8 桁
2. **変えることを先にテストへ書く**（Red で止めてよいのはこのフェーズの新規テストだけ）
   - `sanitizedRatioText`: 上記の表（`1.25` / `1.2.5` / `1234.567` / `9999`）
   - `parseRatio`: `"inf"` 相当の長い 9 列と非有限はドメイン値 0（Interactor 直呼びでも trap しない）
   - Interactor: 倍率 `Decimal` が巨大 / 非有限でも `calculateBill` が return する。既存ハッピーパスは未変更
   - `CollectionState.reconcile`: 同 `groupID` の results が 2 件でも trap しない
   - Presenter: 同 ID の 2 グループを restore / apply 相当で流すと ID が分かれる
   - Presenter: グループ 20 件で `didTapAddGroup` しても件数と計算回数が増えない
   - AdsController: extra slot の `onEarned` が 1 回呼ばれる既存テストは維持（View 循環はコードレビューで見る）

3. プロダクトコードはまだ変えない。フェーズ 1 からグリーンにする。

完了条件:

- 新規テストが新仕様を表現している
- 既存 Interactor 金額テストは **ファイル未変更のまま** グリーン

### フェーズ 1: 倍率と Interactor の trap

目的: キー入力でプロセスが死ぬ経路を先に潰す。

実施内容:

1. `InputLimits.sanitizedRatioText` に桁上限
2. `AttendeeGroupDraft.parseRatio` に `isFinite`
3. Interactor の `Int` / `*` を §3.2 どおり防御。式は有限範囲で現行と同一
4. 走査の 1 本化はフェーズ 5。ここでは trap だけでもよい（1 本化してテストが全部グリーンなら、1 に含めてよい）

完了条件:

- フェーズ 0 の倍率・trap テストがグリーン
- 既存金額テストがグリーン
- 本番に新しい `!` が無い

### フェーズ 2: 広告スレッドと循環参照

目的: リワード / インタースティシャル完了で View も AdsController も落とさない。

実施内容:

1. AdsController の Task / SDK コールバックを §3.6
2. `SakuttoSplitView.presentExtraSlotRewarded` から View メソッド捕獲を除去
3. `needsSaveMemberSetNamePrompt` と消費 Intent。Unlock 成功後に保存名 Alert が出る現行 UX は維持
4. Undo バナー Task を `onDisappear` で cancel

完了条件:

- extra slot の既存 AdsController テストがグリーン
- リワード完了後に保存名 Alert が出る（目視または View に近いテスト）
- `presentRewarded` に渡すクロージャが View の `self` を捕獲していないことをレビューで確認（`let presenter = self.presenter` パターン）

### フェーズ 3: 重複 ID と reconcile 1 回

目的: 破損データと復元経路のクラッシュ・二重 publish を消す。

実施内容:

1. groups uniquify（§3.3）
2. `Dictionary(..., uniquingKeysWith:)`
3. `applyUpdate(paidSeatKeys:)` に復元・編成・Undo を集約。呼び出し側の二度目を削除
4. `memberSetUndo` を編成適用の直後に入れる順序は維持

完了条件:

- 重複 ID テストがグリーン
- 既存の復元 paid キー / 編成適用で席が未払いに戻るテストがグリーン
- `didTapRestoreLastBill` / `didTapApplyMemberSet` / `didTapUndoMemberSetApply` に `reconcileCollection` が **二重に無い**

### フェーズ 4: パフォーマンス（ユーザーに見える重さ）

目的: 起動・保存・席トグル・グループ追加で無駄なデコードと View 増加を止める。

実施内容:

1. `makeSessionChrome` の `lastBill` 1 回読み
2. `groupMaxCount = 20` と追加ボタン disabled。20 超の restore/apply は先頭 20
3. 未払いシェア文のキャッシュ（§3.8）
4. CollectionSection の grouping とハプティクス再利用（§3.9）

完了条件:

- グループ 20 件テストがグリーン
- 席トグルでメインシェア文が変わらない既存テストがグリーン
- `makeSessionChrome` 内の `sessionStore.lastBill` が 1 回

### フェーズ 5: Swift らしい同等書き換え

目的: 結果を変えずに読みやすさだけ上げる。

実施内容:

1. Interactor 1 走査（フェーズ 1 で済んでいれば no-op）
2. `ShareTextBuilder` を `map` + `joined`。`ShareTextBuilderTests` の文字列を変更しない
3. `CountStepper` プラスの `.disabled`

完了条件:

- ShareText / Interactor / Count の既存テストがグリーン
- 計算期待値を変えるコミットがこのフェーズに混ざっていない

---

## 6. テスト計画

| 対象 | フェーズ | 内容 |
| --- | --- | --- |
| InputLimits | 0–1 | 倍率の表。既存 `1.2.5` → `1.25` は残す |
| AttendeeGroupDraft | 0–1 | 非有限・空・`"."` は ratio 0 |
| Interactor | 0–1 | 巨大倍率でも return。既存金額ファイルは未変更 |
| CollectionState | 0–3 | 重複 `groupID` で trap しない |
| Presenter | 0–3 | 重複 ID の restore で id がユニーク。編成 Undo・paid キー既存 |
| Presenter | 0–4 | 20 件で add しても count / spy 計算が増えない |
| AdsController | 2 | extra slot onEarned / dismiss 既存。weak Task はレビュー |
| ShareTextBuilder | 5 | 文面完全一致 |
| CountStepper | 5 | 必須にしない。プレビューまたは既存 UI テストで上限 disabled |

計算カウンタ（`CalculatingSpyInteractor`）をフェーズ 3–4 でも使い、uniquify やキャッシュで **計算回数が増えていない** ことを固定する。

---

## 7. リスクと移行方針

| リスク | 対策 |
| --- | --- |
| 倍率桁制限で `1.250` が `1.25` になる | 既定値は `1.0`。3 桁小数を使っている UI 経路は無い。復元値は編集まで触らない |
| uniquify で paid キーが外れる | 後続 ID だけ振り直す。先頭の済は残る。テストで明示 |
| 20 超の編成を切る | 保存済み 21 件目が見えなくなる。現状 UI で 21 件を作る手段は連打のみ。上限と同時に追加を止める |
| `@MainActor` hop で onEarned が 1 フレーム遅れる | 報酬付与の順序（earn → finish で pending クリア）は現行と同じ。既存テストの同期呼び出しが落ちるなら、テスト側で `await` する |
| chrome フラグを消し忘れる | Alert の出た / キャンセルで必ず消費 Intent。`didTapSettleComplete` では触らなくてよい |
| 巨大 PR | フェーズごとに PR。0 はテストのみ |

ブランチ戦略（推奨）:

1. `fix/safety-tests`（フェーズ 0）
2. `fix/safety-ratio-trap`（フェーズ 1）
3. `fix/safety-ads-lifetime`（フェーズ 2）
4. `fix/safety-ids-reconcile`（フェーズ 3）
5. `fix/safety-perf`（フェーズ 4）
6. `fix/safety-idiom`（フェーズ 5）

---

## 8. 優先度

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | フェーズ 0 のテスト | 期待値を先に固定する |
| P0 | 倍率桁 + Interactor trap | ユーザー入力で即死 |
| P0 | 広告 MainActor + View 非捕獲 | リワード経路のクラッシュと循環 |
| P1 | 重複 ID + reconcile 1 回 | 破損データと二重 publish |
| P1 | グループ上限 20 | Form / 回収ボードの線形増加 |
| P2 | lastBill 1 回 / 未払い文キャッシュ / grouping | 重さ。正しさは既にある |
| P3 | ShareText `joined` / CountStepper disabled | 読みやすさ |

---

## 9. 完了の定義

本計画の完了とは、次をすべて満たす状態を指す。

1. 有限でない倍率・`Int` に収まらない按分でも `calculateBill` が trap しない
2. UI から入る倍率は整数 3 桁・小数 2 桁に正規化される
3. Google 広告の完了 / 報酬コールバックがメインアクター以外から `@Published` を書かない
4. `AdsController.pendingOnEarned` が View の `self` を保持しない
5. `viewState.groups` の id が一意。`uniqueKeysWithValues` がコードベースに無い
6. 復元・編成適用・Undo で `reconcileCollection` が Intent あたり 1 回
7. グループは最大 20。追加ボタンは上限で押せない
8. 既存 Interactor 金額テストとシェア文テストがグリーン
9. Presenter が GoogleMobileAds を import していない

---

## 10. 次のアクション

実装開始時は、このファイルのフェーズ単位で PR を切り、完了したフェーズにチェックを付ける。

最初の実装コミットはフェーズ 0（テストのみ）とする。プロダクトコードはフェーズ 1 から。

レビュー指摘の「推奨修正案」と本ファイルが衝突したら、**本ファイルの §2 / §3 を正本**とする。
