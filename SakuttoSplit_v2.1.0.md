# SakuttoSplit v2.0.0 会計継続 実装計画書（第2スライス）

- 対象: 現行の単一 VIPER モジュール `Modules/SakuttoSplit` と、永続化・メンバーセット UI。広告は `AdsController` を拡張するだけ
- 作成日: 2026-09-14
- 改訂: 2026-09-14 — **Store リリースは 2.0.0 にまとめる**。本スライスを 2.1.0 として分けて出さない
- 前提: `SakuttoSplit_v2.0.0.md` の広告実装（第1スライス）は完了済み（バナー連動 / 精算完了 / インタースティシャル / 24h 広告オフ）
- 入力: v2.0.0 計画書 §11 の開発ストック（幹事価値順）と、精算完了が生んだ新しい痛み
- 方針: **この文書ではコード実装を行わない**。実装者が迷わないよう、仕様・責務・手順・完了条件だけを固定する
- 評価観点: 入力からシェアまでのタップ数を増やさない / 計算ロジックを変えない / 広告ルール（第1スライス）を壊さない / VIPER の境界を壊さない

第1スライスは広告、本スライスは会計の継続である。どちらも **同じ 2.0.0** に含めて出す。`MARKETING_VERSION` は本スライス完了後に **2.0.0** へ上げる（2.1.0 にはしない）。

目的は、**今夜の会計が消えないこと** と、**よく使う編成を次の宴会でも一発で出せること** である。リワード動画の「見る理由」を広告オフ以外に 1 つ足す。IAP・OCR・画像シェアは 2.0.0 の範囲外。

---

## 0. なぜこれを次にするか

v2.0.0 で「精算完了（次の会計へ）」を足した。二次会のリセットは必要だが、同時に次が起きた。

| 起きること | 現場 |
| --- | --- |
| 精算完了で入力が初期状態に戻る | PayPay 待ちの途中で押すと、台帳が消える |
| プロセスキル / 電話割り込み | もともと保存がない。結果画面を開いたまま落ちると再入力 |
| 毎回「部長 / 一般」を手で直す | 初期テンプレが需要の証拠。保存手段がない |

v2.0.0 §11 の先頭 2 件（前回復元 / メンバーセット）は、この痛みに直結する。端数ルール追加や OCR より先にやる。

広告オフ用リワードは残す。テンプレ保存は **別の視聴理由** にする（視聴したら保存できる。広告オフは付与しない）。

---

## 1. 現状サマリ（v2.0.0 完了後）

| 項目 | 現状 |
| --- | --- |
| 画面 | `SakuttoSplitView` のみ。シェア / 精算完了 / 広告オフ toolbar |
| 状態の寿命 | プロセス内の Presenter のみ。UserDefaults は `ads.adFreeUntil` だけ |
| 精算完了 | 妥当なら `viewState = .initial` して再計算。直前の会計は残らない |
| 起動 | 常に initial（部長 10000 / 一般 1.0×4 / 総額空） |
| リワード | 「今日の広告をオフ」のみ。報酬種別を差し替える口がない |
| 計算 | Interactor 純関数。1 Intent = 1 計算。変更しない |
| アプリ版 | `MARKETING_VERSION = 1.0.1`。本スライス込みで **2.0.0** に上げて提出する |

広告の出し方（キーボード中バナーなし、精算完了後だけ全画面、任意リワード）は **契約として維持する**。本計画でインタースティシャルのトリガーを増やさない。

---

## 2. プロダクト方針（先に決めること）

実装中にひっくり返さない。

### 2.1 採用する

| 判断 | 理由 |
| --- | --- |
| **前回会計の自動保存 + ワンタップ復元は無料** | 復旧機能を動画の後ろに隠すと、精算完了の事故が greate になる |
| 保存するのは **入力スナップショット**（総額・端数・グループ）。結果・シェア文は保存しない | 復元時に再計算すればよい。結果 identity も作り直せる |
| 精算完了の **直前** に必ずスナップショットする | リセットで消える会計を、復元の正本にする |
| バックグラウンド遷移時、入力が妥当なら上書き保存する | PayPay 中のキルに耐える |
| 起動時は **自動復元しない** | 新しい会計を始めたい人の邪魔をしない |
| メンバーセットは **グループ編成 + 端数単位**。総額は含めない | 店が変わるたびに総額は違う |
| 無料スロット 1 + リワードで永続スロット追加（上限 3） | 「見る理由」になる。IAP の前段 |
| リワード視聴の報酬は、入口ごとに 1 種類だけ | テンプレ保存視聴で広告オフを付けない。逆も同様 |
| テンプレ適用は現在のグループを置き換える。総額は維持 | 総額入力済みで編成だけ変える操作がある |
| 永続化は端末内 `UserDefaults` + JSON。アカウントなし | 現行 Ads と同じ。同期もログインも作らない |

### 2.2 採用しない（本スライス / 2.0.0 禁止）

| 判断 | 理由 |
| --- | --- |
| IAP（広告削除・無制限テンプレ） | 2.0.0 出荷後。今回は無料 1 + リワード上限 3 で受け皿だけ作る |
| 履歴一覧（日付付きの複数会計） | 前回 1 件で足りる。一覧は画面追加が大きい |
| 起動時の自動復元 | 新しい会計の開始を遅らせる |
| キー入力のたびに Disk 書き込み | 計算 1 回と Disk 1 回を同期させない。保存点は区切りだけ |
| 端数の四捨五入 / 切り上げ | 計算仕様変更。別計画 |
| シェア画像 / OCR / チェックリスト / ルーレット / 個人名展開 | §11 の後続。本計画で画面を増やしすぎない |
| App Open / シェア時全画面 / ATT | v2.0.0 禁止を踏襲 |
| テンプレ保存を広告オフと同じ toolbar ボタンに相乗り | 報酬が混ざる |
| iCloud / ファイルエクスポート | 範囲外 |

### 2.3 UX の絶対ルール

1. 総額入力 → シェアまでのタップ数は今と同じ。復元・テンプレは任意
2. シェア（緑全幅）より、復元もテンプレも目立たせない
3. 1 人あたり金額の上に広告もテンプレ UI も差し込まない
4. 精算完了の直後にインタースティシャルが出る契約は変えない。保存は present の前に同期で終わらせる
5. 動画はユーザーが「保存するために見る」と分かっているときだけ
6. 計算式・初期グループ・シェア文面は変えない

---

## 3. 仕様

### 3.1 用語

| 用語 | 意味 |
| --- | --- |
| スナップショット | 総額テキスト、端数単位、グループ Draft の配列。結果は含まない |
| 前回会計 | スロット 1 の自動保存。常に最新の「妥当な会計」1 件 |
| メンバーセット | 名前付きの編成。グループ + 端数。総額なし |
| スロット | メンバーセットの保存枠。無料 1、リワードで最大 3 |

### 3.2 前回会計（無料）

#### 保存

次のとき、現在の入力が `validationIssue == nil` なら `BillSnapshot` で上書きする。

1. **精算完了の直前**（リセットより前。必須）
2. **scenePhase が `.background` になったとき**
3. **妥当な状態でアプリが terminate される前** は 2 に含めてよい（`inactive` でも可）。入力のたびに書かない

保存しない。

- 総額空、グループ 0、固定額超過
- initial そのもの（空の総額）で、既存の前回会計を消さない

同一内容なら書き込まなくてよい（Equatable でスキップ可）。

#### 復元

| 項目 | 仕様 |
| --- | --- |
| 入口 | ナビゲーション左上、または参加者セクション先頭の二次ボタン。シェア・精算完了・広告オフより弱い |
| 文言 | `session.restore` = `前回の会計を復元` |
| 有効 | 前回スナップショットが存在する |
| 無効 | スナップショットなし。ボタンは隠す（disabled で残さない） |
| タップ | スナップショットを ViewState の入力へ流し込み、計算 1 回。フォーカス解除 |
| 上書き確認 | 現在が initial（精算直後・起動直後）なら確認なし。現在が initial でなく、かつ前回と入力が違うなら確認アラート |

確認コピー:

- タイトル `session.restore_confirm_title` = `入力中の内容を置き換えます`
- メッセージ `session.restore_confirm_message` = `前回保存した会計に戻します。今の入力は消えます。`
- 実行 `session.restore` / キャンセルはシステム `Cancel`

復元後のグループ ID はスナップショットの UUID を使う（新規 UUID に振り直さない）。フォーカス identity が安定する。

#### 起動

今までどおり initial を出す。バナー下やスプラッシュで自動復元しない。前回があるときだけ復元ボタンが見える。

### 3.3 メンバーセット

#### データ

```text
MemberSet
  id: UUID
  name: String          // ユーザー命名。空なら「セットn」
  roundingUnit: RoundingUnit
  groups: [AttendeeGroupDraft]  // id は保存時のものを保持
  createdAt: Date       // 並び用。編集しても維持してよい
```

総額・結果・シェア文は持たない。

#### 枠

| 枠 | 仕様 |
| --- | --- |
| 無料 | 1 |
| リワード追加 | 1 回の視聴完了で **永続スロット +1** |
| 上限 | 3（無料 1 + リワード 2） |
| 既に 3 | 保存ボタンは「上限に達しています」。動画を出さない |
| 広告オフ中 | スロット追加の視聴はできる（報酬は枠であり広告オフではない） |
| 削除 | セットは消える。スロット数は減らさない（一度広げた枠は維持） |

「今回だけ保存」ではなく、枠そのものが残る。アプリ再起動後も 3 枠のまま。

#### UI

参加者グループセクションの「グループを追加」の下（または右上メニュー）に次を置く。

- `set.save` = `この編成を保存`
- `set.load` = `保存した編成を使う`

保存:

1. グループが 1 件以上あること（総額は空でも可。固定額超過でも編成は保存してよい）
2. 空き枠がある → 名前入力（プリフィル `set.default_name %lld`）→ 確定で保存
3. 空き枠がない、かつ上限未満 → 「動画を見て保存枠を 1 つ増やす」確認 → 視聴完了 → 名前入力 → 保存
4. 上限 → アラートのみ

適用:

- シートで一覧（名前、グループ数）
- タップで適用。総額は今の値を維持。端数とグループをセットの内容に置き換え、計算 1 回
- スワイプ削除（確認あり）
- 適用確認は、現在グループが initial の既定 2 件と違うときだけ出す

シートは新 VIPER モジュールにしない。同じ Presenter の Intent + `sheet` で足りる。

#### リワードとの接続

視聴理由のコピーは広告オフと取り違えない。

- `set.reward_title` = `保存枠を 1 つ増やす`
- `set.reward_message` = `動画を最後まで見ると、編成を保存できる枠が 1 つ増えます。`
- 視聴完了前にセットを書かない
- 途中閉じは枠も保存もしない
- 未 load は既存 `ads.reward_unavailable` を使う

広告オフトoolbar（`video.slash`）の挙動は v2.0.0 のまま。

### 3.4 精算完了との順序（契約）

現行 View:

```text
focusedField = nil
presenter.didTapSettleComplete()
adsController.presentInterstitialIfEligible(from:)
```

新仕様:

```text
focusedField = nil
presenter.didTapSettleComplete()
  └─ 内部で (1) 妥当なら snapshot 保存 (2) state = .initial
adsController.presentInterstitialIfEligible(from:)
```

保存失敗（エンコード失敗）でもリセットと広告提示は行う。ユーザーに保存エラーダイアログは出さない（ログのみでよい）。前回が残らないのは次の会計で復元ボタンが消えることで分かる。

### 3.5 ローカライズ（追加キー）

ソース言語は現行どおり en キー + 日本語 value。

| キー | value |
| --- | --- |
| `session.restore` | `前回の会計を復元` |
| `session.restore_confirm_title` | `入力中の内容を置き換えます` |
| `session.restore_confirm_message` | `前回保存した会計に戻します。今の入力は消えます。` |
| `set.save` | `この編成を保存` |
| `set.load` | `保存した編成を使う` |
| `set.name_placeholder` | `セット名（例: いつもの飲み会）` |
| `set.default_name %lld` | `セット%lld` |
| `set.reward_title` | `保存枠を 1 つ増やす` |
| `set.reward_message` | `動画を最後まで見ると、編成を保存できる枠が 1 つ増えます。` |
| `set.slot_full_title` | `保存できる編成は 3 件までです` |
| `set.slot_full_message` | `使わない編成を削除してください。` |
| `set.delete_confirm` | `この編成を削除しますか？` |
| `set.empty` | `保存した編成はまだありません` |
| `set.apply_confirm_title` | `今のグループを置き換えます` |
| `set.apply_confirm_message` | `保存した編成を適用します。今のグループ入力は消えます。総額はそのままです。` |

既存キー（シェア、精算完了、広告オフ）は変えない。

### 3.6 永続化フォーマット

キーは `AdFreeStore` と同様、型の隣に定数で 1 箇所。

| キー | 内容 |
| --- | --- |
| `session.lastBill` | `BillSnapshot` の JSON `Data` |
| `session.memberSets` | `[MemberSet]` の JSON `Data` |
| `session.memberSetSlotCount` | `Int`（1...3）。未設定は 1 |

スキーマバージョンを `BillSnapshot` / `MemberSet` に `schemaVersion: 1` を入れる。読めないデータは無視して空扱い（クラッシュしない）。マイグレーションは 2.0.0 では不要。

`AttendeeGroupDraft` / `PaymentMode` / `RoundingUnit` を `Codable` にする。計算結果 Entity は Codable にしない。

---

## 4. アーキテクチャ

計算 Presenter に UserDefaults も GoogleMobileAds も直接書かない。広告オフ期限と同じく、Store を挟む。

```text
App / View
  ├─ scenePhase .background → presenter.didEnterBackground()
  ├─ 復元ボタン → presenter.didTapRestoreLastBill()
  ├─ 編成を保存 → presenter.didTapSaveMemberSet(...) または枠不足なら Ads へ
  └─ 精算完了 → presenter.didTapSettleComplete() → 広告（現行）

Presenter
  ├─ BillSessionStoring に依存（last bill / sets / slotCount）
  ├─ didTapSettleComplete の先頭で saveLastBillIfValid
  ├─ 復元・適用・保存・削除の Intent
  └─ 広告 SDK は知らない。枠追加の動画は View が AdsController に依頼

BillSessionStore（新設）
  └─ UserDefaults。テストは suiteName 注入（AdFreeStore と同じ）

AdsController
  └─ presentRewarded(from:purpose:) を追加。
     purpose: adFree24h | extraMemberSetSlot
     完了時に該当報酬だけ付与。既存 didTapHideAdsForToday は adFree24h の薄ラッパ
```

### 4.1 責務

| 層 | 内容 |
| --- | --- |
| Entity | `BillSnapshot`, `MemberSet`。Draft / PaymentMode / RoundingUnit の Codable |
| Store | JSON の読み書き、スロット数。計算も広告も知らない |
| Presenter | いつ保存するか、復元で state をどう置き換えるか。1 Intent = 1 計算は維持 |
| View | ボタン、確認アラート、シート、リワード提示の順序（枠追加だけ） |
| AdsController | リワードの load / present / 目的別コールバック。スロット数は書かない |
| Interactor | **変更しない** |

枠追加の順序（採用 B。v2.0.0 の精算完了と同じく View が SDK 境界）:

1. View: 空き枠なし & 上限未満を Presenter の `viewState` または Store 由来の表示状態で知る
2. 確認後 `adsController.presentRewarded(from:purpose: .extraMemberSetSlot)`
3. 完了コールバックが成功したときだけ `presenter.didUnlockMemberSetSlot()` → 名前入力へ

Presenter が「動画を出せ」と Ads を呼ぶ循環は作らない。

### 4.2 ViewState に Disk を混ぜない

`SakuttoSplitViewState` に JSON やスロット数を足しすぎない。表示に必要なものだけ別の小さく `@Published` するか、同じ Presenter に `sessionState` を 2 つ目の Published として足す。

推奨:

```text
SakuttoSplitPresenter
  @Published viewState          … 現行。計算の正本
  @Published sessionChrome      … hasLastBill, memberSets, slotCount, isMemberSetSheetPresented
```

`applyUpdate` の計算経路に sessionChrome を載せない。復元・適用のときだけ `applyUpdate` で入力を書き換える。

### 4.3 リワード目的の拡張

現行は `onDidEarnReward` が常に `grantAdFree()`。これを提示前の `pendingReward` に変える。

```text
enum RewardedPurpose: Equatable {
    case adFree24h
    case extraMemberSetSlot
}
```

- `didTapHideAdsForToday` → purpose `.adFree24h`（期限中は再生しない。現行どおり）
- 枠追加 → purpose `.extraMemberSetSlot`（広告オフ中でも再生してよい）
- 同時 present は 1 本。`presentingRewarded != nil` なら無視（現行ガード維持）
- 途中閉じ: pending を捨て、どの Store も書かない
- 完了: purpose に応じて Ads または Presenter へ。スロット書き込みは Presenter/Store。AdsController は「成功した」ことだけ返す

実装しやすい形:

```text
func presentRewarded(
    from rootViewController: UIViewController,
    purpose: RewardedPurpose,
    onEarned: (() -> Void)? = nil
)
```

`onEarned` は枠追加用。広告オフは Controller 内で grant。テストは FakeRewarded の `onDidEarnReward` で既存どおり。

### 4.4 ファイル配置（予定）

| ファイル | 役割 |
| --- | --- |
| `Entity/BillSnapshot.swift`（新設） | 入力スナップショット。schemaVersion |
| `Entity/MemberSet.swift`（新設） | 名前付き編成 |
| `Entity/AttendeeGroupDraft.swift` ほか | `Codable` 追加 |
| `Session/BillSessionStore.swift`（新設） | UserDefaults。Ads 配下に置かない |
| `Ads/AdsContract.swift` / `AdsController.swift` | `RewardedPurpose` と汎用 present |
| `Modules/SakuttoSplit/Presenter/SakuttoSplitPresenter.swift` | 保存点・復元・セット Intent |
| `Modules/SakuttoSplit/Presenter/SakuttoSplitSessionChrome.swift`（新設・任意） | シート用の薄い状態 |
| `Modules/SakuttoSplit/Contract/SakuttoSplitContract.swift` | Intent 追加 |
| `Modules/SakuttoSplit/View/SakuttoSplitView.swift` | 復元ボタン、background、リワード接続 |
| `Modules/SakuttoSplit/View/Subviews/MemberSetSheet.swift`（新設） | 一覧・削除・適用 |
| `Modules/SakuttoSplit/View/Subviews/GroupListSection.swift` | 保存 / 使う |
| `Localizable.xcstrings` | 3.5 のキー |
| `Router` | Store を Presenter に注入。Module DTO は Ads を壊さない |

`GoogleMobileAds` の import 許可は v2.0.0 と同じ（App / AdBannerView / AdsController）。Session Store に SDK を入れない。

---

## 5. フェーズ

フェーズごとに PR を切る。計算期待値を変えるコミットと永続化を混ぜない。

### フェーズ 0: スナップショット契約とテスト先書き

目的: Disk の形と「いつ保存するか」をテストで固定する。

実施内容:

1. `BillSnapshot` / `MemberSet` の Codable ラウンドトリップ
2. Store: lastBill の save/load/clear。壊れた Data は nil
3. Store: sets の CRUD、slotCount 初期 1、unlock で 2 なら 3 まで、4 にはならない
4. Presenter テスト（まだ Red でよい）: 妥当な状態で `didTapSettleComplete` すると、リセット後でも lastBill に精算前の総額・グループが残る
5. 妥当でない精算（既存ガード）では lastBill を変えない
6. `didEnterBackground` は妥当なときだけ書く

完了条件:

- 既存 Interactor テストは未変更でグリーン
- プロダクトの画面はまだ変わらない（型と Store とテストのみ可）

### フェーズ 1: 前回会計の保存と復元（無料）

目的: 精算完了とキルに対する安全網を先に出す。リワードは触らない。

実施内容:

1. Presenter に Store を注入（Router）。デフォルト `BillSessionStore()`
2. `didTapSettleComplete` で保存してから initial
3. `didEnterBackground`
4. `didTapRestoreLastBill`（必要なら `confirming:` は View 側）
5. View: 左上またはセクション二次ボタン。`hasLastBill` のときだけ
6. scenePhase `.background` で Intent
7. 確認アラート（initial 以外）
8. xcstrings の session.* キー

完了条件:

- 総額入りの会計を精算完了 → 画面は initial → 復元で精算前に戻る
- 総額空のまま background しても、以前の妥当な lastBill を消さない
- シェア・精算完了・バナー・インタースティシャルの契約が手動チェックで不変
- 1 Intent = 1 計算（復元は計算 1 回）

### フェーズ 2: メンバーセット（無料 1 枠）

目的: 編成の保存・適用・削除。動画はまだ出さない。

実施内容:

1. 空き枠があるときの保存（名前入力）
2. シートから適用（総額維持）
3. 削除確認
4. 枠が 1 のとき 2 件目は「枠がない」とだけ出す（リワード接続はフェーズ 3）
5. 上限コピーはまだ出さなくてよい

完了条件:

- 部長/一般を名前付きで保存し、グループを崩したあと適用で戻る。総額は維持
- 再起動後もセットが残る
- 無料枠を超える保存は Disk に書かれない

### フェーズ 3: リワードでスロット追加

目的: 2 件目以降の保存を、視聴完了にだけ結びつける。

実施内容:

1. `RewardedPurpose`
2. `didTapHideAdsForToday` が `.adFree24h` のまま動く回帰テスト
3. 枠追加フロー（確認 → present → onEarned → slotCount + 1 → 名前入力）
4. 途中閉じで slotCount 不変
5. slotCount == 3 で動画を出さない
6. 広告オフ中でも枠追加視聴は可
7. xcstrings の set.reward_* / slot_full_*

完了条件:

- 広告オフ視聴でスロットが増えない
- 枠追加視聴で広告オフ期限が延びない
- 1 回の完了で slotCount が 1 だけ増える
- 未 load は既存の「読み込めませんでした」

### フェーズ 4: 仕上げ

目的: 配布できる状態にする。

実施内容:

1. README に「前回復元（無料）」「メンバーセット（1 + リワードで最大 3）」を広告節の隣に短く書く
2. `MARKETING_VERSION` を **2.0.0** にする（2.1.0 にはしない。広告スライスと同一提出）
3. 実機: 精算完了 → 全画面 → 復元、テンプレ適用、リワード 2 種類の取り違えがないこと
4. 壊れた UserDefaults を仕込んでも起動できること

完了条件:

- セクション 8 を満たす
- 広告 grep 許可リストが Session ファイルを含まない

---

## 6. ファイル別対応マップ

| 現状 | 変更 | フェーズ |
| --- | --- | --- |
| 永続化が `ads.adFreeUntil` のみ | `BillSessionStore` を追加 | 0–1 |
| `didTapSettleComplete` が即 initial | 直前に lastBill 保存 | 1 |
| 起動・精算後に戻る手段なし | 復元 Intent + ボタン | 1 |
| scenePhase は広告オフ refresh のみ | 妥当時スナップショット | 1 |
| グループ追加だけ | 保存 / 使う | 2 |
| Rewarded 報酬が広告オフ固定 | `RewardedPurpose` | 3 |
| README が広告のみ | 復元とセットを追記 | 4 |

触らないもの:

- `SakuttoSplitInteractor` の計算式
- デフォルト initial グループ
- `ShareTextBuilder` の日本語
- 精算完了以外のインタースティシャル
- キーボード中バナー非表示
- 人数 1...999、総額 8 桁、1 Intent = 1 計算
- 本番広告ユニット ID と `GADApplicationIdentifier`

---

## 7. テスト計画

SDK は叩かない。Store は `UserDefaults(suiteName:)`。

| 対象 | フェーズ | 内容 |
| --- | --- | --- |
| BillSnapshot Codable | 0 | 総額・端数・複数グループ・同名グループ（id で区別） |
| BillSessionStore | 0 | 壊れた Data → lastBill nil、sets 空。slot 4 にならない |
| Presenter 精算 | 1 | 妥当な精算後 `viewState` は calculated initial。Store の lastBill は精算前 |
| Presenter 精算ガード | 1 | 総額空では state も lastBill も不変（既存 last がある場合は残す） |
| Presenter background | 1 | 妥当なら書く。不正なら書かない |
| Presenter 復元 | 1 | lastBill の総額・人数が viewState に戻り、計算 1 回、シェア可能 |
| Presenter セット適用 | 2 | 総額維持、グループ置換、計算 1 回 |
| Presenter セット保存 | 2 | 空きなしなら sets.count 不変 |
| Presenter unlock | 3 | `didUnlockMemberSetSlot` で 1→2。3 のとき不変 |
| AdsController | 3 | purpose adFree では grantAdFree のみ。extraSlot では grantAdFree しない。中断はどちらも不変 |
| 既存 | 全期間 | Interactor / 人数 / シェア文 / AdEligibility / 精算ガード |

手動:

1. 会計を入れてシェア。ホームへ。キル。再起動。初期画面のまま。復元で戻る。金額が一致
2. 精算完了。全画面（15 秒・load 済み時）。閉じると initial。復元で精算前
3. 総額空でバックグラウンド。以前の前回を消していない
4. 編成を 1 件保存。グループを崩して適用。総額は残る
5. 2 件目保存で動画。最後まで見て保存できる。途中閉じでは 2 件目が増えない
6. 広告オフ動画を見る。スロットは増えない。バナーは消える
7. 枠追加動画を見る。バナーは消えない（オフ未付与）
8. キーボード中バナーなし、シェア前に全画面なし（v2.0.0 回帰）

---

## 8. 完了の定義

2.0.0 第2スライスの実装完了とは、次をすべて満たす状態を指す。Store 提出は第1スライス（広告）と合わせて行う。

1. 妥当な会計は、精算完了とバックグラウンドで 1 件残る。起動は initial のまま
2. 前回があるとき、任意操作でその入力に戻れる。結果は再計算される
3. メンバーセットを無料 1 件保存・適用・削除できる。総額は適用で変わらない
4. 2 件目以降の枠はリワード完了時だけ増え、上限 3。広告オフとは報酬が混ざらない
5. 計算 Interactor・初期グループ・シェア文・広告トリガーが第1スライスと同一
6. Presenter が `GoogleMobileAds` を import しない。Session Store も import しない
7. 壊れた保存データで起動しても落ちない
8. README が復元とメンバーセットの制限を説明している

---

## 9. リスクと移行方針

| リスク | 対策 |
| --- | --- |
| 精算完了後に保存すると空を書いてしまう | **リセット前** に書く。テストで総額の残存を固定 |
| 入力のたびに Disk | background と精算だけ。レビューで `applyUpdate` 内 save を禁止 |
| 復元がシェアより目立つ | 左上テキストボタン / セクション二次。緑はシェア専用 |
| リワード目的の取り違え | purpose enum とテストで分離。コピーも分離 |
| Codable 追加で Draft の `id` が変わる | 明示的に encode。復元で UUID を維持 |
| 同名グループ | 結果 identity は現行どおり groupID。スナップショットも id を持つ |
| Store を Ads に寄せてキーが衝突 | `session.*` プレフィックス。Ads は `ads.*` のまま |
| 巨大 PR | フェーズ 0→4。1 完了時点で「消えない会計」として価値がある |
| 広告未提出のまま版を 2.1.0 にしてしまう | 版は 2.0.0 固定。提出は本スライス完了後に一度だけ |

ブランチ戦略（推奨）:

1. `feat/v2-session-contracts`（フェーズ 0）
2. `feat/v2-last-bill`（フェーズ 1）
3. `feat/v2-member-sets`（フェーズ 2）
4. `feat/v2-rewarded-slots`（フェーズ 3）
5. `feat/v2-session-docs-version`（フェーズ 4。`MARKETING_VERSION = 2.0.0`）

---

## 10. 実装時のレビュー用 grep

```text
import GoogleMobileAds
```

許可は v2.0.0 と同じ。`BillSessionStore` / Presenter / MemberSetSheet に出たら差し戻す。

```text
UserDefaults
```

許可: `AdFreeStore`、`BillSessionStore`、そのテスト。Presenter 直書きは不可。

```text
applyUpdate
```

中で Store を呼ばない（精算完了は `didTapSettleComplete` 内で save → `applyUpdate { $0 = .initial }`）。

```text
grantAdFree
```

`.adFree24h` 以外から呼ばない。

---

## 11. Store 提出

**2.0.0 は本スライス込みで一度だけ出す。** 広告だけを先に 2.0.0 として提出しない。実装時点の `MARKETING_VERSION` は 1.0.1 のままなので、フェーズ 4 で **2.0.0** に上げる。

提出作業（スクリーンショット更新、プライバシーラベル、審査メモ）は実装フェーズに含めないが、ショットは復元ボタンとメンバーセットが見える画面も撮る。

---

## 12. この次（2.0.0 出荷後・実装しない）

2.0.0 を出したあと、第1スライス計画書 §11 の残りを価値順で拾う。

| 順 | 候補 | 理由 |
| --- | --- | --- |
| 1 | IAP 買い切り（広告オフ永続 + セット無制限） | 枠 3 と 24h オフの受け皿が揃う |
| 2 | 回収チェックリスト | シェア後の待機時間をプロダクトにする |
| 3 | 端数の四捨五入 / 切り上げ | 計算仕様。テスト先行必須 |
| 4 | シェア画像 | デザイン作業が大きい |
| 5 | OCR / 複数店舗 / ルーレット / 個人名 | 別画面・権限・エンタメ。急がない |

---

## 13. 次のアクション

実装開始時は、このファイルのフェーズ単位で PR を切り、完了したフェーズにチェックを付ける。

最初の実装コミットはフェーズ 0（`BillSnapshot` / Store / 精算時保存のテスト）とする。画面の復元ボタンはフェーズ 1 から。リワード目的の拡張はフェーズ 3 まで触らない（フェーズ 1–2 で広告オフが壊れないようにする）。

---

## 14. 実施記録

- 2026-09-14: **フェーズ 0 完了**。`BillSnapshot` / `MemberSet` の Codable、`BillSessionStoring` + `BillSessionStore`、精算完了・background の妥当時保存テストがグリーン。復元ボタン・scenePhase・xcstrings は未着手（フェーズ 1）。
- 2026-09-14: **フェーズ 1 完了**。前回会計の復元 Intent、左上ボタン（`hasLastBill` のときだけ）、initial 以外の確認アラート、`scenePhase == .background`、`session.*` キー。リワードとメンバーセットは未着手。
- 2026-09-14: **フェーズ 2 完了**。メンバーセット無料 1 枠の保存・適用（総額維持）・削除。空きなしは「枠がない」のみ（リワード未接続）。
- 2026-09-14: **フェーズ 3 完了**。`RewardedPurpose`（広告オフ / 枠追加）。枠追加は視聴完了時だけ slotCount +1。途中閉じ・上限 3・広告オフ中の枠追加を分離。
