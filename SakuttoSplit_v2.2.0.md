# SakuttoSplit v2.0.0 回収チェックリスト 実装計画書（第3スライス）

- 対象: 計算結果の下に置く「誰が払ったか」ボード。永続化は現行 `BillSnapshot` / `BillSessionStore` を拡張する
- 作成日: 2026-09-14
- 前提: 第1スライス（広告、`SakuttoSplit_v2.0.0.md`）と第2スライス（会計継続、`SakuttoSplit_v2.1.0.md`）は完了済み
- 方針: **この文書ではコード実装を行わない**。実装者が迷わないよう、仕様・責務・手順・完了条件だけを固定する
- 評価観点: 入力からシェアまでのタップ数を増やさない / 計算ロジックを変えない / 広告ルールと前回復元を壊さない / VIPER の境界を壊さない

**Store リリースは 2.0.0 にまとめる。** 本スライスを 2.2.0 として分けて出さない。`MARKETING_VERSION` はすでに 2.0.0 なので、**上げない**（2.1.0 / 2.2.0 にもしない）。

目的は、シェア後の PayPay 待ちを「金額を眺めるだけ」から **回収ボード** に変えることである。IAP・OCR・端数ルール追加・画像シェアは範囲外。

---

## 0. なぜこれを次にするか

いまの 2.0.0 には、広告と「消えない会計」がある。現場の残り穴はここである。

| 起きること | 現場 |
| --- | --- |
| シェアしたあと、結果画面を開いたまま送金を待つ | 誰が払ったかをアプリが持たない。幹事が頭と LINE で管理する |
| 精算完了でリセット → 復元 | 金額は戻るが、回収の途中経過は残らない |
| バナーが確認中だけ出る | 待ち時間の滞在は長い。ボードがあれば、その時間に画面を閉じなくて済む |

第2スライス計画の「この次」でも、IAP の前に回収チェックリストが幹事価値で並んでいた。IAP は審査と StoreKit が増えるので、**同じ 2.0.0 に足すならボードの方が先**である。端数の四捨五入は計算仕様変更なので、ボードより後にする。

---

## 1. 現状サマリ（第2スライス完了後）

| 項目 | 現状 |
| --- | --- |
| 結果セクション | 1 人あたり / 余剰不足 / シェア / 精算完了。回収 UI なし |
| シェア文 | グループ単位の金額と PayPay 依頼。未払い者リストなし |
| 前回会計 | 総額・端数・グループのみ。`BillSnapshot.schemaVersion = 1` |
| Store | `isCurrentSchema` が **ちょうど 1 だけ** 通す。版を上げると前回が消える |
| 計算 | 割合は切り捨てのみ。Interactor は触らない |
| 広告 | キーボード中バナーなし。全画面は精算完了後のみ |
| アプリ版 | `MARKETING_VERSION = 2.0.0` |

---

## 2. プロダクト方針（先に決めること）

実装中にひっくり返さない。

### 2.1 採用する

| 判断 | 理由 |
| --- | --- |
| チェックリストは **無料**。リワードの後ろに隠さない | 送金中の台帳を動画の後ろに置くと、精算完了と同じ事故になる |
| 席はグループ人数から自動展開する。個人名の手入力はしない | 「個人名展開」は別ストック。今回は 一般×4 → 一般 1…4 |
| 人数が多いグループは展開せず、グループ 1 行で済/未済 | 999 人のチェックは使えない。閾値は `InputLimits` に置く |
| ボードは **シェアボタンの下、精算完了の上** | 数字とコア CTA の間に入れない。精算より前に置く（リセットで消えるため） |
| チェック操作は計算を走らせない | 済/未済は金額を変えない。1 Intent = 1 計算を壊さない |
| 済/未済は前回会計スナップショットに含める | キルと精算完了→復元で回収途中が戻る |
| 未払いだけ再シェアは無料の二次ボタン | IAP 前段にしない。待ち時間の本命 CTA |
| 全画面広告のトリガーは精算完了のまま | 最後の 1 人をチェックしただけでは出さない |
| schema 1 の前回は読める。保存時だけ新しいフィールドを書く | 開発中・内部ビルドの lastBill を消さない |

### 2.2 採用しない（本スライス / 2.0.0 禁止）

| 判断 | 理由 |
| --- | --- |
| IAP | StoreKit と審査を 2.0.0 初回に載せない。枠 3 と 24h オフの受け皿は次リリース |
| 席ごとの名前編集 | 個人名展開と同じ作業量になる |
| 端数の四捨五入 / 切り上げ | 計算仕様。Interactor テストを本スライスに混ぜない |
| シェア画像 / OCR / ルーレット / 複数店舗 | 画面と権限が増える |
| チェック時・未払いシェア時の全画面 | 待ち時間の台帳を隠す |
| 起動時に回収ボードを自動復元表示 | 起動は initial のまま（第2スライス契約） |
| 入力のたびに Disk | 保存点は現行どおり精算直前と background。チェック後もこの 2 点に乗る |
| チェックを `applyUpdate` に乗せる | 不要な再計算が走る |

### 2.3 UX の絶対ルール

1. 総額入力 → メインのシェアまでのタップ数は今と同じ。ボードは任意
2. 緑全幅はメインのシェア専用。未払い再シェアは `.bordered`
3. 1 人あたり金額の行より上にチェックを置かない
4. 妥当でない入力（総額空など）ではボードを出さない
5. 精算完了の全画面契約は第1スライスのまま

---

## 3. 仕様

### 3.1 席（Seat）

1 グループは、人数に応じて席になる。

| 条件 | 行の作り方 |
| --- | --- |
| `count <= collectionExpandMaxCount`（**20**） | 席を `count` 行。ラベルは `collection.seat_label` = `%@ %lld`（例: `一般 1`） |
| `count > 20` | 展開しない。グループ 1 行。ラベルはグループ名。チェック 1 つでそのグループ全員 |

同一グループ内の席 index は **0 始まり**。表示番号は **1 始まり**。

席 ID（永続化キー）:

```text
"{groupID.uuidString}:{index}"
```

展開しないグループは index `0` の 1 席だけとする。

金額は常にそのグループの `amountPerPerson`。グループ合計は行に出さなくてよい（結果セクションに既にある）。

### 3.2 表示

新しいセクション `section.collection`（文言: `回収`）。

置く位置（`CalculationResultSection` 内の順）:

1. 結果行（現行）
2. 過不足（現行）
3. バリデーション（現行）
4. メインシェア（現行・緑）
5. **回収セクション（本スライス）** — `validationIssue == nil` のときだけ
6. 精算完了（現行）

各席行:

- チェック（済 = on）
- ラベル
- 1 人あたり金額（結果行と同じ書式 `result.per_person %lld`）

セクション末尾:

- 進捗 `collection.progress %lld %lld` = `未払い %lld / %lld`
- `collection.share_unpaid` = `未払いだけ再シェア`。未払いが 1 席以上かつメインシェアが有効なときだけ enabled
- 全員済のときは進捗を `collection.all_paid` = `全員回収済み` にし、未払いシェアは disabled

キーボード中もボードは Form 内なのでスクロールできる。バナー規則は変えない。

### 3.3 操作と同期

| 操作 | 席の扱い |
| --- | --- |
| チェック ON/OFF | その席だけ。計算しない |
| グループ人数を増やす | 末尾に未払い席を足す |
| グループ人数を減らす | 末尾の席を捨てる。残った席の済は維持 |
| グループ削除 | その groupID の席を捨てる |
| グループ名変更 | ラベルだけ更新。済は維持 |
| メンバーセット適用 | グループ ID が変わるので席は作り直し（すべて未払い） |
| 前回復元 | スナップショットの済キーを載せる。今いない席 ID は捨てる |
| 精算完了 | 保存（済を含む）してから initial。ボードは空（初期グループは総額空なので非表示） |
| 計算結果の金額が変わる | 席 ID は維持。表示金額だけ追従 |

初期状態（総額空）ではボードを出さない。

### 3.4 未払い再シェア

メインのシェア文は **変えない**（第1・第2スライスの文面契約）。

未払い用は別ビルダー。例:

```text
🍻 未払いのお願い 🍻
総額: 35000 円
----------------
一般 2: 1人 6200円
一般 4: 1人 6200円
----------------
※PayPay等で送金をお願いします！
```

全員済・ボード非表示のときは空文字で、ボタンは disabled。

`ShareLink` はメインと分け、緑背景にしない。`ShareResultButton` に相乗りしない（`listRowBackground` の既知制約を増やさない）。

### 3.5 永続化

`BillSnapshot` に任意フィールドを足す。

```text
paidSeatKeys: [String]   // 済の席 ID。未払いは載せる必要なし
```

- デコード: キーが無い schema 1 は `[]`
- エンコード: 常に書く
- `schemaVersion`: **保存時は 2**。読み込みは **1 と 2 を受理**
- `BillSessionStore.lastBill` の `isCurrentSchema` を「現行だけ」から「1...current を受理」に変える。**1 を nil にしてはいけない**
- 読めない JSON は現行どおり nil / 空

メンバーセットには済/未済を持たない（編成であり今夜の回収ではない）。

保存タイミングは現行のまま（妥当なときだけ）:

1. 精算完了の直前
2. `scenePhase == .background`

チェックのたびに UserDefaults を書かない。background 前にチェックした内容は 2 で残る。プロセスキル前に background が来ないケースは OS 次第で、第2スライスと同じ割り切り。

### 3.6 ローカライズ

| キー | value |
| --- | --- |
| `section.collection` | `回収` |
| `collection.seat_label %@ %lld` | `%@ %lld` |
| `collection.progress %lld %lld` | `未払い %lld / %lld` |
| `collection.all_paid` | `全員回収済み` |
| `collection.share_unpaid` | `未払いだけ再シェア` |

既存のシェア文・精算完了・広告・復元キーは変えない。

### 3.7 上限

```text
InputLimits.collectionExpandMaxCount = 20
```

Presenter / 席の生成だけが参照する。Interactor は知らない。人数入力の 1...999 は変えない。

---

## 4. アーキテクチャ

計算の `viewState` にチェック配列を混ぜない。混ぜると入力のたびに席まで Equatable 比較し、Intent の意味が壊れる。

```text
Presenter
  @Published viewState          … 現行。計算の正本
  @Published sessionChrome      … 現行。復元・セット
  @Published collectionState    … 新設。席の済/未済（計算しない）

applyUpdate のあと reconcileCollection()
  現在の groups + results から席リストを作り、
  既存の isPaid を席 ID で引き継ぐ

didTapToggleCollectionSeat(id)
  collectionState だけ更新。applyUpdate を呼ばない

makeSnapshot()
  済の席 ID を paidSeatKeys に入れる

didTapRestoreLastBill
  入力を戻して計算したあと、paidSeatKeys を載せ直す
```

### 4.1 責務

| 層 | 内容 |
| --- | --- |
| Entity | `CollectionSeatID`, `CollectionSeat`, `CollectionState`。`BillSnapshot.paidSeatKeys` |
| Interactor | **変更しない** |
| Presenter | 席の reconcile、トグル、スナップショット、未払いシェア文 |
| View | セクション描画、未払い `ShareLink`。資格判定ロジックは持たない |
| Ads | **変更しない** |
| Store | schema 1...2 を読む。キー名は現行 `session.lastBill` のまま |

未払いシェア文は `ShareTextBuilder` にメソッドを足してよい。メイン `build(from:)` の出力はテストで現状固定したままにする。

### 4.2 ファイル配置（予定）

| ファイル | 役割 |
| --- | --- |
| `Entity/CollectionSeat.swift`（新設） | ID / 席 / 状態 |
| `Entity/BillSnapshot.swift` | `paidSeatKeys`、schema 2、v1 互換デコード |
| `Session/BillSessionStore.swift` | schema 1...current を受理 |
| `Config/InputLimits.swift` | `collectionExpandMaxCount` |
| `Presenter/ShareTextBuilder.swift` | `buildUnpaid(...)` 追加。メイン文面は不変 |
| `Presenter/SakuttoSplitPresenter.swift` | reconcile / toggle / snapshot |
| `Contract/SakuttoSplitContract.swift` | `didTapToggleCollectionSeat` と collection 公開 |
| `View/Subviews/CollectionSection.swift`（新設） | 席行 + 進捗 + 未払いシェア |
| `View/Subviews/CalculationResultSection.swift` | セクションを差し込む |
| `Localizable.xcstrings` | 3.6 のキー |
| `README.md` | 回収ボードを 1 節で追記 |

`GoogleMobileAds` の許可リストは変えない。Collection に SDK を入れない。

---

## 5. フェーズ

フェーズごとに PR を切る。計算期待値とボードを混ぜない。

### フェーズ 0: 席の契約と schema 互換のテスト先書き

目的: 展開規則と「古い lastBill が消えないこと」を先に固定する。

実施内容:

1. 人数 1 / 4 / 20 / 21 の席数（21 は 1 行）
2. 席 ID の文字列形式
3. `BillSnapshot` の schema 1 JSON（`paidSeatKeys` なし）がデコードでき、`paidSeatKeys == []`
4. schema 2 を書いて読む
5. Store: 既存の schema 1 Data を `lastBill` が nil にしない
6. 未払いシェア文の期待値（メイン文面テストは未変更）

完了条件:

- 既存 Interactor / 精算保存 / 復元テストはグリーン
- 画面はまだ変わらない

### フェーズ 1: Presenter の席状態（UI なしでテスト可能に）

目的: reconcile とトグルとスナップショットを Presenter だけで完了させる。

実施内容:

1. `collectionState` を Presenter に追加
2. 総額を入れて妥当になったら席が生まれる
3. トグルは計算回数 0（spy）
4. 人数 4→5 で未払い席が 1 つ増える。4→3 で末尾が消える。残った済は維持
5. 精算完了後、Store の `paidSeatKeys` に精算前の済が残る。画面の collection は空（非表示相当）
6. 復元で済が戻る
7. セット適用で済がクリアされる

完了条件:

- 1 Intent = 1 計算が、トグルでは増えない
- メイン `shareText` がトグルで変わらない

### フェーズ 2: UI

目的: 結果セクションにボードと未払いシェアを出す。

実施内容:

1. `CollectionSection`
2. `CalculationResultSection` のシェアと精算の間に挿入
3. バリデーション中は出さない
4. 未払い `ShareLink`（disabled 条件どおり）
5. xcstrings
6. Preview（少人数 / 全員済 / 非表示）

完了条件:

- 緑シェアの見た目・文言・有効条件が不変
- 精算完了の位置がボードより下
- キーボード中にバナーが出ない（回帰）

### フェーズ 3: 仕上げ

目的: 2.0.0 に載せる。

実施内容:

1. README に回収ボード（無料、人数 20 超はグループ 1 行、未払い再シェア）を短く書く
2. `MARKETING_VERSION` は **2.0.0 のまま**
3. 手動チェックリストを通す

完了条件:

- セクション 8 を満たす

---

## 6. ファイル別対応マップ

| 現状 | 変更 | フェーズ |
| --- | --- | --- |
| `BillSnapshot` に済がない | `paidSeatKeys`、schema 2、v1 デコード | 0–1 |
| Store が schema ちょうど 1 のみ | 1...current を受理 | 0 |
| Presenter に席状態なし | `collectionState` + toggle + reconcile | 1 |
| 結果がシェア→精算 | 間に回収 | 2 |
| シェア文が 1 種 | 未払い用を追加（メイン不変） | 1–2 |
| README が広告と継続のみ | 回収を追記 | 3 |

触らないもの:

- `SakuttoSplitInteractor` の計算式と端数切り捨て
- デフォルト initial グループ
- メイン `ShareTextBuilder.build` の日本語
- 精算完了以外のインタースティシャル
- キーボード中バナー非表示
- メンバーセットの枠 1...3 とリワード目的
- `MARKETING_VERSION`（2.0.0 のまま）
- 本番広告ユニット ID

---

## 7. テスト計画

| 対象 | フェーズ | 内容 |
| --- | --- | --- |
| 席展開 | 0 | 4 人 → 4 席。21 人 → 1 席。ラベル 1 始まり |
| Snapshot v1 | 0 | `paidSeatKeys` なし JSON が読める |
| Store | 0 | 既存 v1 Data が `lastBill != nil` |
| Presenter トグル | 1 | spy 計算 0 回。`shareText` 不変 |
| Presenter 人数 | 1 | 増減で席が末尾変化。済の引き継ぎ |
| Presenter 精算 | 1 | lastBill に済が残る。collection は initial 相当で空 |
| Presenter 復元 | 1 | 済が戻る。存在しない席 ID は捨てる |
| Presenter セット適用 | 1 | 済がすべて未払い |
| ShareTextBuilder | 1 | メイン文面の既存テスト不変。未払い用は未払い席だけ |
| 既存 | 全期間 | Interactor / 広告資格 / メンバーセット / 精算ガード |

手動:

1. 部長 1 + 一般 4、総額入力。回収に 5 行出る。メインシェアは今までどおり
2. 2 席を済にする。ホームへキル。再起動は initial。復元すると 2 席が済のまま
3. 精算完了（15 秒後なら全画面）。復元すると精算前の済が残る
4. 未払い再シェアの文面に済の席が出ない
5. 全員済にするとボタンが無効、文言が「全員回収済み」
6. 一般を 21 人にすると 1 行になる
7. シェアやチェックでは全画面が出ない。精算完了では出る
8. キーボード中バナーなし

---

## 8. 完了の定義

第3スライスの完了とは、次をすべて満たす状態を指す。2.0.0 提出は本スライス込みで行う。

1. 妥当な会計で、人数に応じた席の済/未済を付けられる。計算結果は変わらない
2. メインシェアの文面・見た目・タップ数は第2スライスと同じ
3. 未払いだけ再シェアできる。全員済では出せない
4. 精算完了と background で済が前回会計に残る。復元で戻る。起動は initial
5. schema 1 の lastBill が読め、ボードは全部未払いになる
6. 広告トリガー・バナー規則・メンバーセット枠が不変
7. Interactor を変えていない
8. `MARKETING_VERSION` が 2.0.0 のまま
9. README が回収ボードを説明している

---

## 9. リスクと移行方針

| リスク | 対策 |
| --- | --- |
| schema を 2 だけにして lastBill が消える | 読み込みは 1 と 2。テストで v1 JSON を固定 |
| トグルで再計算 | `applyUpdate` 禁止。spy で 0 回 |
| ボードがシェアより目立つ | 緑はメインシェア。ボードはセクションとチェック |
| 人数 999 で Form が死ぬ | グループ 21 人以上は 1 行 |
| 未払いシェアがメインを上書き | 別ボタン・別ビルダー。既存テストを残す |
| チェックのたびに Disk | 保存点は現行の 2 つのまま |
| 巨大 PR | フェーズ 0→3 |

ブランチ戦略（推奨）:

1. `feat/v2-collection-contracts`（フェーズ 0）
2. `feat/v2-collection-presenter`（フェーズ 1）
3. `feat/v2-collection-ui`（フェーズ 2）
4. `feat/v2-collection-docs`（フェーズ 3）

---

## 10. 実装時のレビュー用 grep

```text
import GoogleMobileAds
```

Collection / Snapshot / Presenter に出たら差し戻す。

```text
applyUpdate
```

トグル経路から呼ばない。

```text
isCurrentSchema
```

1 を落とす実装になっていないこと。

```text
ShareTextBuilder.build(
```

既存のメイン文面テストが削除・期待値変更されていないこと。

---

## 11. Store 提出

広告・会計継続・本スライスを **2.0.0 で一度だけ** 出す。版番号は上げない。

提出作業（スクリーンショット、プライバシーラベル）は実装フェーズに含めない。ショットには回収ボードが見える結果画面を足す。

---

## 12. この次（2.0.0 出荷後・実装しない）

| 順 | 候補 | 理由 |
| --- | --- | --- |
| 1 | IAP 買い切り（広告オフ永続 + セット無制限） | 枠と 24h オフと回収ボードが揃ってから |
| 2 | 端数の四捨五入 / 切り上げ | 計算仕様。テスト先行 |
| 3 | 席の個人名 | 今回の席 ID の上に名前を載せる |
| 4 | シェア画像 | デザインが大きい |
| 5 | OCR / 複数店舗 / ルーレット | 権限・別画面 |

---

## 13. 次のアクション

実装者は **このファイルのフェーズ 0 から** 始める。第1・第2スライスの計画はやり直さない。

最初の実装コミットは schema 1 互換と席展開のテストとする。画面はフェーズ 2 から変える。

---

## 14. 実施記録

- **フェーズ 0（完了）**: `CollectionSeat` / 席 ID / `InputLimits.collectionExpandMaxCount`、`BillSnapshot` schema 2 + v1 デコード（`paidSeatKeys == []`）、Store が schema 1...2 を受理、`ShareTextBuilder.buildUnpaid`。画面・Presenter の席状態は未着手。
- **フェーズ 1（完了）**: Presenter に `collectionState` / `didTapToggleCollectionSeat` / 未払いシェア文。妥当な入力で席を生成。トグルは計算 0 回でメイン `shareText` 不変。人数増減で末尾の席が変化し済は維持。精算・background で `paidSeatKeys` を保存し、復元で戻す。セット適用で済をクリア。UI は未着手。
- **フェーズ 2（完了）**: `CollectionSection` を結果セクションの緑シェアと精算完了の間に挿入。妥当なときだけ表示。未払い `ShareLink` は `.bordered`（緑にしない）。xcstrings と Preview（少人数 / 全員済 / 非表示）を追加。バナー規則は未変更。
- **フェーズ 3（完了）**: README に回収ボード（無料、21 人以上はグループ 1 行、未払い再シェア）を追記。`MARKETING_VERSION = 2.0.0` を Info.plist テストで固定。Interactor / 本番広告 ID / バナー規則は未変更。手動チェックリストは自動テストで対応（実機の目視・15 秒後全画面は提出前）。

手動チェックリスト（§7）との対応:
1. 部長 1 + 一般 4 で 5 席、メインシェア文面不変 → PresenterCollection / ShareTextBuilder
2. 済を保存し、起動は initial、復元で済が戻る → PresenterCollection 精算・復元、init は initial
3. 精算完了で lastBill に済が残る。全画面は精算成功後のみ → PresenterCollection + AdsController
4. 未払いシェアに済の席が出ない → ShareTextBuilder / PresenterCollection
5. 全員済で未払いシェア disabled、「全員回収済み」キー → isUnpaidShareEnabled + xcstrings
6. 一般 21 人は 1 行 → CollectionSeat / PresenterCollection
7. シェア・トグルでは全画面なし。精算完了だけ `presentInterstitialIfEligible` → View の呼び出し箇所 + AdsController
8. キーボード中バナーなし → AdBannerSlot
