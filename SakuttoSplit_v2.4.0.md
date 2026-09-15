# SakuttoSplit v2.1.0 継続率 実装計画書（第4スライス）

- 対象: 編成保存オファー、未払いローカル通知、直近会計履歴。計算 Interactor・広告 SDK・`BillSnapshot` の schema 2 は触らない
- 作成日: 2026-09-15
- 前提: 第1スライス（広告）・第2スライス（会計継続）・第3スライス（回収ボード）・UI 改善（`SakuttoSplit_v2.3.0.md`）は完了済み
- 入力: 2026-09-15 の継続率提案（幹事の D1 回収復帰と、次の宴会の D7 / D30）。採用範囲は本ファイル §2 に固定する
- 方針: **この文書ではコード実装を行わない**。実装者が迷わないよう、仕様・責務・手順・完了条件だけを固定する
- 評価観点: 総額入力からメインシェアまでのタップ数を増やさない / 計算ロジックを変えない / 広告ルールと前回会計の保存点を壊さない / VIPER の境界を壊さない / 起動時の自動復元をしない

**Store リリースは 2.1.0。** 本スライスを 2.4.0 として分けて出さない。`MARKETING_VERSION` は本スライス完了時に **2.1.0** へ上げる（2.4.0 にはしない）。2.0.0 が未提出でも、通知許可が入る本スライスは 2.0.0 に混ぜない。

目的は、閉じたあとに戻る理由を 2 つ足すことである。**今夜の未回収** と **次の宴会の顔ぶれ**。IAP・OCR・ウィジェット・Live Activity・リモートプッシュは範囲外。

---

## 0. なぜこれを次にするか

2.0.0 には広告・前回 1 件・編成セット・回収ボードが揃っている。現場に残っている穴は、開いた人を助ける仕組みではなく **閉じたあとに戻す仕組み** である。

| 起きること | 現場 |
| --- | --- |
| 初回シェアで終わる | 編成保存は右上 Menu。次の宴会でまた手入力し、電卓に戻る |
| LINE に貼って PayPay 待ち | 回収ボードは開いた人にしか効かない。未払いの翌日リマインドがない |
| 精算完了で前回が上書きされる | 先月の歓送迎会と同じ顔ぶれを出せない。前回 1 件は今夜専用 |

IAP は「毎月幹事」の受け皿だが、戻る理由がないと課金前に離脱する。継続の導線を先に出し、買い切りは本スライスの次とする。

第2スライスは履歴一覧を 2.0.0 禁止にした。禁止理由は「画面追加が大きい」であり、継続価値がないからではない。本スライスは **MemberSetSheet と同型のシート** に閉じ、Navigation の画面スタックは増やさない。

---

## 1. 現状サマリ（v2.3.0 完了後）

| 項目 | 現状 |
| --- | --- |
| 画面 | 単一 `SakuttoSplitView`。編成は Menu + シート。履歴 UI なし |
| 起動 | 常に initial。前回は再開カード / 左上復元。自動復元しない |
| 前回会計 | `session.lastBill` 1 件。schema 2。済席キーあり。日付なし |
| 編成 | 無料 1 + リワード最大 3。保存は Menu からの名前 Alert |
| シェア | sticky `ShareLink` とキーボード toolbar。完了コールバックなし |
| 回収 | 妥当入力のときだけ。未払い再シェアは `.bordered` |
| 通知 | なし。`UserNotifications` 未使用。Info.plist に通知用キーなし |
| 広告 | バナーはキーボード中非表示。全画面は精算確認成功後のみ |
| 計算 | Interactor 純関数。1 Intent = 1 計算。変更しない |
| アプリ版 | `MARKETING_VERSION = 2.0.0` |

---

## 2. プロダクト方針（先に決めること）

実装中にひっくり返さない。

### 2.1 採用する

| 判断 | 理由 |
| --- | --- |
| 3 機能を **1 リリース** に載せる。実装順はオファー → 通知 → 履歴 | コスト順。途中でも価値が出る。提出は 3 つ揃ってから |
| 編成オファーは **無料枠が空かつセット 0 件** の初回シェア後だけ | 「いつもの飲み会」を知ってもらう。毎回出さない |
| オファーは非モーダルのカード。Alert にしない | 既存の保存名 Alert・通知許可 Alert と積まない |
| メインシェアのトリガーは **ShareLink のタップ** | `ShareLink` に完了コールバックがない。キャンセルしても 1 回だけ扱う |
| 未払い再シェアではオファーも許可 Alert も出さない | 二次 CTA。初回の本命は sticky / キーボードのメインシェア |
| 通知は **ローカルのみ**。サーバーもアカウントも作らない | 現行の永続化と同じ。同期しない |
| 許可の前に自前 Alert を 1 回出す | 起動時システムダイアログは出さない。シェア直後の文脈で説明する |
| 通知は 1 会計あたり 1 通。識別子は固定 | 連打しない。本文の未払い人数だけ更新する |
| 発火は「3 時間後」。0:00–8:59 に当たればその日 10:00 | 宴会の当日夜に間に合わせ、深夜には打たない |
| 履歴は直近 **5 件**。無料。リワードの後ろに隠さない | 戻る理由を動画の後ろに置くと、前回 1 件と同じ事故になる |
| 履歴 UI はシート。起動は initial のまま | 自動復元禁止を踏襲。再開カードは lastBill 専用 |
| lastBill の保存のたびに履歴へ upsert | 精算しない宴会も残る。グループ ID 列が同じなら上書き |
| `BillSnapshot` は schema 2 のまま。日付は履歴エントリが持つ | 前回 1 件の読み込みを壊さない |

### 2.2 採用しない（本スライス / 2.1.0 禁止）

| 判断 | 理由 |
| --- | --- |
| リモートプッシュ / マーケティング通知 / 毎日の「今日も幹事？」 | 許可を燃やす。頻度の低いユーティリティに合わない |
| 起動時・入力中の通知許可 | 文脈がない。シェア前に権限で止める |
| 通知タップで自動復元 | 起動は initial。再開カードが入口 |
| ウィジェット / Live Activity / App Intents | 未払いが古いまま残る。Live Activity は夜をまたげない |
| IAP / OCR / シェア画像 / 席の個人名 / 端数の四捨五入 | 第3スライス「この次」のまま。本スライスに混ぜない |
| 履歴のクラウド同期・書き出し | アカウントなし契約 |
| オファーからリワード枠追加へ誘導 | 初回導線に動画を置かない |
| 新しい VIPER モジュールや Navigation 先画面 | シートで閉じる |
| lastBill キー変更・schema 3 | 表示用日付は履歴側 |
| App Open / シェア時全画面 / ATT | v2.0.0 禁止を踏襲 |
| `NSUserNotificationsUsageDescription` | ローカル通知の許可に Info.plist キーは不要。足さない |
| 通知の in-app バナー（UNUserNotificationCenterDelegate で前面表示） | OS の通知に任せる。前面では出さない |

### 2.3 UX の絶対ルール

実装者が迷ったら、ここに戻る。

1. 総額入力からメインシェアまでのタップ数は今と同じ。オファー・許可・履歴は任意
2. 起動は initial。自動復元しない
3. 1 人あたり金額の上にオファーも履歴も通知 UI も置かない
4. メインシェアは 1 つ。Accent 全幅。未払い再シェアは `.bordered`
5. 全画面は精算確認を経た成功後だけ。オファー保存・通知許可・履歴操作では出さない
6. 計算式・初期グループ・シェア文の項目は変えない
7. 回収ボードの席展開規則（20 以下展開、21 以上 1 行）は不変
8. Presenter は `GoogleMobileAds` も `UserNotifications` も import しない
9. 保存点は現行どおり **精算直前と background**。履歴の upsert もこの 2 点だけ。入力のたびに Disk しない
10. コピーのトーンは居酒屋の幹事向け。「リマインド機能が解放」のようなゲーム文言は使わない

---

## 3. 仕様

### 3.1 用語

| 用語 | 意味 |
| --- | --- |
| メインシェア | sticky またはキーボード toolbar の `ShareLink`。未払い再シェアは含めない |
| シェアタップ | 有効なメインシェアをユーザーが押したこと。システムシートの完了は問わない |
| 編成オファー | セット 0 件の人に、初回シェア後だけ出す保存カード |
| 未払いリマインダー | 未払いが残る会計に対するローカル通知 1 通 |
| 履歴エントリ | 日付付きの `BillSnapshot` 包み。最大 5 |
| 同一会計 | 履歴先頭と、今のスナップショットの `groups.map(\.id)` が列として等しい |

### 3.2 編成オファー

#### 表示条件（すべて満たすときだけ）

1. `sessionStore.memberSets.isEmpty`
2. `hasEmptyMemberSetSlot == true`
3. このプロセスの **この会計** でメインシェアを 1 回以上タップした
4. オファーをまだ消費していない（保存成功 / 閉じる / Disk の消費フラグ）
5. `viewState.groups` が空でない
6. `validationIssue == nil`（シェアできる会計である）

精算完了で initial に戻ったら、この会計のシェアフラグは落ちる。消費フラグが Disk に残っていれば、以降の会計でも出さない。

#### 消費

次のいずれかで、カードを消し `session.memberSetOfferConsumed = true` を書く。

- 保存成功
- カードの閉じる
- 編成を Menu から保存して `memberSets` が 1 件以上になった（オファー外経路）

閉じるだけでセットは作らない。Menu からの保存導線は残る。

#### 出さない

- 未払い再シェア
- セットが 1 件以上ある
- 空き枠がない
- 起動直後・シェア前
- 消費済み

#### 置き場所

回収セクションの **先頭**（進捗や席より上）。1 人あたり金額より下。妥当入力で回収が出るときだけシェアできるので、カードが回収と同時に出る。

回収が何らかの理由で空でもシェアできる状態は現行にない。ガードとして、回収が空なら結果セクション末尾に出してもよいが、通常経路では回収先頭だけ実装すればよい。

#### カード UI

- タイトル `set.offer_title` = `次の飲み会を1タップに`
- 本文 `set.offer_message` = `この顔ぶれを編成として保存できます`
- 主ボタン `set.offer_save` = `保存する`（`.borderedProminent`）
- 閉じるは `xmark`。`accessibilityLabel` は `set.offer_dismiss`
- sticky シェアより目立たせない。結果数字より大きくしない

#### 保存する

1. 既存の名前 Alert を出す（`set.save`）
2. 初期値は `set.offer_default_name` = `いつもの飲み会`（`セット%lld` ではない）
3. 空欄なら `いつもの飲み会` に戻す
4. 成功したらカードを消して消費する
5. 既存の `didTapSaveMemberSet(name:)` を使う。総額は持たない

#### この会計のリセット

精算完了・初期化ではカードを隠す。Disk の消費フラグは消さない。

### 3.3 メインシェアの検知

`ShareLink` の完了は取らない。

- `ShareResultButton` とキーボードの `ShareLink` に `onShareTapped` を足す
- 有効時だけ `presenter.didPerformMainShare()` を呼ぶ
- 無効時は呼ばない
- 実装は `simultaneousGesture(TapGesture())` でよい。ShareLink のシートをブロックしてはいけない
- `ShareResultButton` の `Equatable` は **`shareText` と `isEnabled` だけ**。クロージャは比較しない（既存 Performance テストを壊さない）

未払い再シェアボタンには付けない。

### 3.4 未払いリマインダー

#### 許可

起動では聞かない。メインシェアの直後、次を **すべて** 満たすときだけ自前 Alert を出す。

1. 未払い席が 1 以上
2. システムの許可が `.notDetermined`
3. Disk の `session.didPromptUnpaidReminder == false`

Alert:

- タイトル `notify.unpaid_title` = `未払いを知らせる`
- 本文 `notify.unpaid_message` = `PayPay待ちのあいだ、未払いが残っていたら1回だけ通知します`
- 許可する `notify.unpaid_allow`
- あとで `notify.unpaid_later`（cancel）

どちらを押しても `session.didPromptUnpaidReminder = true` を書く（インストールあたり 1 回）。

- 許可する → `requestAuthorization([.alert, .sound, .badge])`。Granted なら予約。Denied なら以降何もしない
- あとで → 予約しない。再Alertしない。OS ダイアログも出さない

システムダイアログを一度出したら、OS の状態に従う。自前 Alert は出さない。

編成オファーのカードと同時に条件を満たしたら、**許可 Alert を先に出す**。カードは Alert の下にいてよい。Alert を積まない（保存名 Alert とは同時に出さない）。

#### 予約とキャンセル

識別子（固定 1 つ）:

```text
io.github.mw-wakkun.SakuttoSplit.unpaidReminder
```

Presenter は未払い人数が変わるたびにスケジューラへ `sync(unpaidCount:)` する。実処理:

| 条件 | 動作 |
| --- | --- |
| 許可が authorized / provisional でない | pending を消し、何も予約しない |
| `unpaidCount == 0` | pending を消し、バッジ 0 |
| `unpaidCount >= 1` | 同じ ID を置き換え予約。本文の人数を更新 |

予約してよいタイミングは「許可済み」のときだけ。シェア前から未払いがあっても、許可前は予約しない。

精算完了（initial へ戻す直前）は必ず `sync(0)` 相当でキャンセルする。

#### 発火時刻

純関数 `UnpaidReminderSchedule.fireDate(now:calendar:) -> Date`。テスト可能。`Calendar` は注入。デフォルトは `Calendar.current`。

```
candidate = now + 3 時間
candidate の時が 0...8 なら、その暦日の 10:00:00
それ以外は candidate
```

例:

| now | 発火 |
| --- | --- |
| 19:00 | 22:00 |
| 22:00 | 翌日 10:00（+3h が 01:00） |
| 08:00 | 11:00 |
| 07:30 | 10:30（+3h が 10:30 で hour>=9） |

`UNCalendarNotificationTrigger(repeats: false)`。過去日時は予約しない（テストの freeze で now より前になったらキャンセル相当）。

#### 通知の中身

- タイトル `notify.unpaid_push_title` = `サクッと割り勘`
- 本文 `notify.unpaid_push_body %lld` = `未払いが%lld人います。回収ボードで確認してください`
- サウンド: デフォルト
- バッジ: `unpaidCount`
- thread / category は作らない
- タップ: アプリが通常起動するだけ。自動復元しない

前面表示用の Delegate は実装しない。

#### 人数の定義

回収ボードと同じ。`collectionState.seats` の未済数。21 人以上のグループ 1 行は席 1 として数える（現行ボードと一致）。

### 3.5 会計履歴

#### データ

新しい型 `BillHistoryEntry`:

```text
schemaVersion: Int = 1
id: UUID
savedAt: Date
snapshot: BillSnapshot   // schema 2 のまま
```

キー: `session.billHistory`（JSON 配列、新しい順）。

上限: `BillSessionStore.maxHistoryCount = 5`。

壊れた JSON / 読めない schema は空配列。エントリ単位で、`snapshot.isReadableSchema == false` のものは捨てる。

`BillSnapshot` に `savedAt` を足さない。schema は 2 のまま。`oldestReadableSchemaVersion = 1` も変えない。

#### upsert 規則

`saveLastBill` の成功後に必ず呼ぶ（精算直前と background）。入力のたびに呼ばない。

1. 履歴先頭の `snapshot.groups.map(\.id)` が今の `groups.map(\.id)` と等しい → 先頭の `snapshot` と `savedAt` を上書き。`id` は維持
2. そうでなければ先頭に insert。6 件目以降を捨てる
3. 妥当でない入力では `saveLastBill` しないので、履歴も触らない

精算完了: 現行どおりリセット前に `saveLastBill` → 履歴に今夜が残る → initial。グループ ID が変わるので、次の妥当な会計は新しいエントリになる。

`clearLastBill` は履歴を消さない（現行コードにほぼ呼び出しがないことを維持し、足しても履歴は残す）。

#### シート

Menu に `history.open` = `会計の履歴` を、編成の保存/読込の **次の Section** に置く（広告オフより上）。

`MemberSetSheet` と同型。`NavigationStack` + `List`。

空: `history.empty` = `まだ履歴はありません`

各行:

- 主: `YenFormatting` した総額（正本は数字文字列のまま）
- 副: `M月d日` + `MemberSet` と同じ編成プレビュー（グループ名と人数、端数）
- 未払いが 1 以上なら tertiary で `history.unpaid %lld` = `未払い %lld人`

行タップは「この会計を続ける」。確認 Alert は **dirty のときだけ**（左上復元と同じ）。initial なら即復元。

スワイプ:

- `history.continue` 相当は行タップに任せる
- leading または confirmation で `history.start_composition` = `同じ編成で始める`
- trailing 削除。確認 `history.delete_confirm`

実装を迷わせないため、行の主操作とスワイプを次に固定する。

| 操作 | 動き |
| --- | --- |
| 行タップ | この会計を続ける（総額・端数・グループ・済を復元。計算 1 回） |
| スワイプ leading | 同じ編成で始める |
| スワイプ trailing | 削除確認 |

同じ編成で始める:

- 総額は **空**（店が変わる。メンバーセットと同じ思想）
- 端数とグループ Draft（id 含む）を載せる
- 済は空。席は作り直し
- 今の総額を捨てるので、dirty なら確認 Alert `history.composition_confirm_title` / `history.composition_confirm_message`
- 適用後 4 秒 Undo（編成適用と同じバナーを流用してよい。文言は `history.composition_applied` / `set.undo`）

この会計を続ける:

- `didTapRestoreLastBill` と同じ流し込み。対象が履歴の snapshot
- lastBill もその snapshot で上書き（再開カードと一致させる）
- シートを閉じる

削除:

- そのエントリだけ消す
- それが lastBill と同一会計（グループ ID 列が等しい）でも lastBill は消さない。履歴と前回は別

#### 再開カード

lastBill 専用のまま。履歴 2 件目をカードに出さない。

### 3.6 永続化キー

既存を壊さない。追加だけ。

| キー | 型 | 意味 |
| --- | --- | --- |
| `session.lastBill` | Data | 不変 |
| `session.memberSets` | Data | 不変 |
| `session.memberSetSlotCount` | Int | 不変 |
| `session.billHistory` | Data | 本スライス |
| `session.memberSetOfferConsumed` | Bool | 本スライス。未設定は false |
| `session.didPromptUnpaidReminder` | Bool | 本スライス。未設定は false |

Ads の `ads.*` には触れない。

### 3.7 文言一覧（xcstrings）

`sourceLanguage` は現行どおり。値は日本語を `en` に入れる（既存キーと同じ）。

| キー | 値 |
| --- | --- |
| `set.offer_title` | 次の飲み会を1タップに |
| `set.offer_message` | この顔ぶれを編成として保存できます |
| `set.offer_save` | 保存する |
| `set.offer_dismiss` | 閉じる |
| `set.offer_default_name` | いつもの飲み会 |
| `notify.unpaid_title` | 未払いを知らせる |
| `notify.unpaid_message` | PayPay待ちのあいだ、未払いが残っていたら1回だけ通知します |
| `notify.unpaid_allow` | 許可する |
| `notify.unpaid_later` | あとで |
| `notify.unpaid_push_title` | サクッと割り勘 |
| `notify.unpaid_push_body %lld` | 未払いが%lld人います。回収ボードで確認してください |
| `history.open` | 会計の履歴 |
| `history.empty` | まだ履歴はありません |
| `history.unpaid %lld` | 未払い %lld人 |
| `history.start_composition` | 同じ編成で始める |
| `history.delete_confirm` | この履歴を削除しますか？ |
| `history.composition_confirm_title` | 同じ編成で始めますか？ |
| `history.composition_confirm_message` | 今の入力を置き換えます。総額は空になります |
| `history.composition_applied` | 編成を適用しました |
| `history.restore_confirm_title` | この会計を続けますか？ |
| `history.restore_confirm_message` | 今の入力を置き換えます |

日付の `M月d日` は `FormatStyle` で出し、xcstrings に固定文を置かない。

既存キー（`set.save` / `set.undo` / `session.restore*` / シェア文）は流用できるものは流用し、意味が違う確認だけ新しいキーにする。

---

## 4. 責務と境界

### 4.1 置いてよいもの

| 部品 | 責務 |
| --- | --- |
| `BillHistoryEntry` | 日付と snapshot。計算しない |
| `BillSessionStore` | lastBill / セット / 履歴 / オファー消費 / 通知プロンプト済み。UserDefaults の `session.*` はここだけ |
| `UnpaidReminderSchedule` | 発火時刻の純関数。Foundation のみ |
| `UnpaidReminderScheduling` | 許可状態の読み取り、許可リクエスト、`sync(unpaidCount:)`、キャンセル |
| `UnpaidReminderScheduler` | `UserNotifications` の唯一の実装。バッジもここ |
| `SakuttoSplitPresenter` | Intent。オファー表示フラグ。シェアタップ。履歴の restore / composition / delete。`sync` 呼び出し |
| View | カード・Alert・シートの表示。ShareLink のタップ転送。許可 Alert のボタンから scheduler の request を Task で呼ぶ |
| Router | Presenter に Store と **本番スケジューラ** を注入 |

### 4.2 置いてはいけないもの

| 部品 | 禁止 |
| --- | --- |
| Presenter | `import UserNotifications` / `import UIKit` / `import GoogleMobileAds` |
| `UnpaidReminderScheduler` | 計算、Store の直接読み（未払い人数は引数で受け取る） |
| Interactor | 本スライスで変更なし |
| `BillSnapshot` | フィールド追加 |
| AdsController | 通知・履歴・オファー |

### 4.3 Presenter の追加 Intent

```text
didPerformMainShare()
didDismissMemberSetOffer()
didTapOpenHistorySheet()
didTapCloseHistorySheet()
didTapRestoreHistory(id:)
didTapStartHistoryComposition(id:)
didTapUndoHistoryComposition()
didTapDeleteHistory(id:)
didConsumeUnpaidReminderPrompt()
```

chrome に足す表示用フラグ:

```text
showsMemberSetOffer: Bool
needsUnpaidReminderPrompt: Bool
isHistorySheetPresented: Bool
history: [BillHistoryEntry]
hasConsumedMemberSetOffer: Bool
```

`showsMemberSetOffer` は chrome か計算プロパティのどちらでもよい。View が `if presenter.showsMemberSetOffer` で描ければよい。条件は §3.2。シェア済みフラグは Presenter のプロセス内状態（Disk にしない）。消費フラグは Disk。

### 4.4 スケジューラの注入

既存テストを実通知に繋がない。

```text
Presenter の sessionStore 付き convenience は
  reminderScheduler: NullUnpaidReminderScheduler
Router.assembleModule だけ UnpaidReminderScheduler()
```

`NullUnpaidReminderScheduler` はテストバンドルでもアプリバンドルでもよいが、本番 Router から使わない。アプリ側に置くなら `sync` が no-op であることをテストする。

許可リクエストは async。Presenter は同期のままにする。View:

1. `needsUnpaidReminderPrompt` で Alert
2. 許可する → `Task { granted = await scheduler.requestAuthorizationIfNeeded(); ... }`
3. granted なら `presenter.didEnterBackground()` 相当ではなく、今の未払い人数で `scheduler.sync` する口を Presenter に `didCompleteUnpaidReminderAuthorization(granted:)` として 1 つ足してよい

迷わないため、次に固定する。

```text
func didCompleteUnpaidReminderAuthorization(granted: Bool)
```

- プロンプト消費フラグを Disk に書くのは、Alert の両ボタンで View が呼ぶ `didConsumeUnpaidReminderPrompt()` が先
- granted なら `sync(unpaidCount: collectionState.unpaid)`
- false なら `sync(0)`

### 4.5 回収変更時の sync

`setCollectionState` の末尾で、Null でないスケジューラへ `sync` する。許可前は実装側が no-op にする。

これでトグル・全員済・復元・精算後の空席が、予約の更新とキャンセルになる。チェック操作は計算しない契約を維持する（`applyUpdate` を呼ばない）。

### 4.6 Router

```text
SakuttoSplitPresenter(
  interactor:,
  sessionStore: BillSessionStore(),
  reminderScheduler: UnpaidReminderScheduler()
)
```

既存のテスト用 init（`sessionStore:` まで）は Null スケジューラ。署名追加はデフォルト引数で既存テストをコンパイルさせる。

---

## 5. フェーズ計画

巨大 PR にしない。**フェーズ 1 完了時点でオファーだけ出荷可能なコード** になるが、Store 提出はフェーズ 4 まで待つのが本計画の完了定義である。

### フェーズ 0: 契約とテスト先書き

目的: 仕様をテストに固定してから View を触る。

実施内容:

1. `BillHistoryEntry` + Codable テスト（snapshot schema 1/2 を包める、壊れた配列は空）
2. `BillSessionStore` に履歴・2 つの Bool キー。`UserDefaults(suiteName:)` でテスト
3. upsert 規則のテスト（同一 ID 列は上書き、違う列は insert、6 件目切り）
4. `UnpaidReminderSchedule.fireDate` の境界テスト（§3.4 の表）
5. `UnpaidReminderScheduling` と Null / Spy
6. xcstrings のキー追加（View 未接続でよい）
7. `InfoPlistAdsTests.testMarketingVersion_Is2_0_0` は **フェーズ 4 まで 2.0.0 のまま**。ここでは版を上げない

完了条件:

- 既存の lastBill / セット / 広告テストが緑
- Store が履歴キーを読んでも lastBill を消さない
- `UserNotifications` をまだ import しなくてよい（Schedule は Date だけ）

### フェーズ 1: 編成オファー

目的: 初回シェア後にセット 0 件へ保存を見せる。通知も履歴も出さない。

実施内容:

1. `didPerformMainShare`
2. `ShareResultButton` / キーボード ShareLink のタップ
3. `showsMemberSetOffer` とカード `MemberSetOfferCard`
4. 保存は既存 Alert。初期名 `いつもの飲み会`
5. 閉じる / 保存成功 / Menu 保存で消費
6. 未払い再シェアでは `didPerformMainShare` を呼ばない
7. Presenter テスト: セットあり・消費済み・シェア前・再シェアではカードが出ない

完了条件:

- セット 0 でメインシェアすると回収先頭にカード
- 保存すると Menu の編成に 1 件。カードが消える。再起動後も出ない
- 閉じると再起動後も出ない
- シェアまでのタップ数は不変
- 精算完了の全画面契約は不変

### フェーズ 2: 未払いローカル通知

目的: 許可済みかつ未払いがある会計だけ、3 時間後（深夜回避）に 1 通。

実施内容:

1. `UnpaidReminderScheduler`（`UserNotifications` はこのファイルだけ）
2. 自前 Alert → requestAuthorization
3. `setCollectionState` / 精算 / 認可完了から `sync`
4. バッジのセットとクリア
5. Spy で「未払い 0 なら cancel」「人数変更で置き換え」「許可前は予約しない」「プロンプトは 1 回」
6. 実機以外で UNUserNotificationCenter の本物は叩かない

完了条件:

- シェア直後、未払いあり・未プロンプトなら Alert。起動時は出ない
- あとでを押すと、以降のシェアで Alert も予約も増えない
- 許可後に全員済へすると pending が消える（Spy の cancel 回数で固定）
- Presenter に `import UserNotifications` がない

### フェーズ 3: 直近 5 件の履歴

目的: 精算や次の宴会で消える顔ぶれを、シートから戻す。

実施内容:

1. `saveLastBill` 後の upsert（Store 内。Presenter は今と同じ `saveLastBillIfValid` だけ）
2. Menu `history.open` と `BillHistorySheet`
3. 続ける / 同じ編成 / 削除
4. dirty 時の確認 Alert
5. 同じ編成の Undo 4 秒
6. 再開カードは lastBill のまま
7. Presenter テスト: 精算後 history.count が増える、同一セッション background は count 不変で済キーだけ更新、6 件目で古いものが落ちる

完了条件:

- 宴会 A を精算 → 宴会 B を入力 → 履歴から A の編成を適用すると総額空・グループは A
- 履歴から A を続けると総額も済も戻る
- 起動は initial。自動で履歴を載せない
- 計算 1 Intent = 1 計算。続ける / 編成適用は各 1 回

### フェーズ 4: 仕上げ

目的: 配布できる状態にする。

実施内容:

1. README にオファー・ローカル通知・履歴 5 件を短く書く。リモートプッシュではないことを明示
2. `MARKETING_VERSION` と `CFBundleShortVersionString` を **2.1.0**
3. `InfoPlistAdsTests.testMarketingVersion_Is2_0_0` を 2.1.0 に更新
4. `NSUserTrackingUsageDescription` が無いこと、GAD ID 不変は維持
5. 手動チェックリスト（§7）

完了条件:

- セクション 8 を満たす
- grep 許可リストを満たす

---

## 6. ファイル別対応マップ

| 現状 | 変更 | フェーズ |
| --- | --- | --- |
| 永続化が lastBill + セット | 履歴配列と Bool 2 つ | 0 |
| 発火時刻の仕様がコードにない | `UnpaidReminderSchedule` | 0 |
| メインシェアに Intent がない | `didPerformMainShare` + ShareLink タップ | 1 |
| 編成保存が Menu のみ | 回収先頭のオファーカード | 1 |
| 通知なし | Scheduler + Alert + sync | 2 |
| 前回 1 件だけ | 履歴シート 5 件 | 3 |
| README が 2.0.0 機能まで | 継続 3 点を追記 | 4 |
| 版 2.0.0 | 2.1.0 | 4 |

新規ファイル（名前はこれで固定する）:

| ファイル | 役割 |
| --- | --- |
| `SakuttoSplit/Entity/BillHistoryEntry.swift` | 履歴エントリ |
| `SakuttoSplit/Reminders/UnpaidReminderContract.swift` | プロトコルと Null |
| `SakuttoSplit/Reminders/UnpaidReminderSchedule.swift` | 発火時刻 |
| `SakuttoSplit/Reminders/UnpaidReminderScheduler.swift` | UserNotifications |
| `SakuttoSplit/Modules/SakuttoSplit/View/Subviews/MemberSetOfferCard.swift` | オファー |
| `SakuttoSplit/Modules/SakuttoSplit/View/Subviews/BillHistorySheet.swift` | 履歴シート |
| `SakuttoSplitTests/BillHistoryEntryTests.swift` | Codable / 読み飛ばし |
| `SakuttoSplitTests/UnpaidReminderScheduleTests.swift` | 発火時刻 |
| `SakuttoSplitTests/UnpaidReminderSchedulerTests.swift` | Spy 経由の予約規則（本物の Center は叩かない） |
| `SakuttoSplitTests/SakuttoSplitPresenterOfferTests.swift` | オファー表示 |
| `SakuttoSplitTests/SakuttoSplitPresenterHistoryTests.swift` | 履歴 Intent |

既存を拡張:

| ファイル | 変更 |
| --- | --- |
| `BillSessionContract.swift` / `BillSessionStore.swift` | 履歴と Bool |
| `InMemoryBillSessionStore.swift` | 同契約 |
| `SakuttoSplitSessionChrome.swift` | オファー / 履歴 / 通知プロンプト |
| `SakuttoSplitContract.swift` / `SakuttoSplitPresenter.swift` | Intent |
| `SakuttoSplitView.swift` | カード・Alert・Menu・シート |
| `ShareResultButton.swift` | onShareTapped。Equatable 明示 |
| `SakuttoSplitRouter.swift` | 本番スケジューラ注入 |
| `Localizable.xcstrings` | §3.7 |
| `BillSessionStoreTests.swift` | upsert / 壊れた履歴 |
| `SakuttoSplitPresenterTests.swift` | 既存がコンパイルできること。詳細は新ファイルへ分けてよい |
| `InfoPlistAdsTests.swift` | フェーズ 4 で 2.1.0 |
| `README.md` | フェーズ 4 |

触らないもの:

- `SakuttoSplitInteractor` の計算式
- デフォルト initial グループ（部長 1 / 10,000、一般 4 / 1.0）
- `ShareTextBuilder` の項目とレシート調
- 精算完了以外のインタースティシャル
- キーボード中バナー非表示
- 人数 1...999、総額 8 桁、1 Intent = 1 計算
- 本番広告ユニット ID と `GADApplicationIdentifier`
- `BillSnapshot.currentSchemaVersion = 2`
- ATT

---

## 7. テスト計画

SDK も UNUserNotificationCenter の本物も叩かない。Store は `UserDefaults(suiteName:)`。スケジューラは Spy。

| 対象 | フェーズ | 内容 |
| --- | --- | --- |
| BillHistoryEntry Codable | 0 | snapshot 付き。schema 不明は Store 側で捨てる |
| Store 履歴 | 0 | 壊れた Data → 空。upsert 上書き / insert / 上限 5 |
| Store Bool | 0 | 未設定は false。true を書いたら再読込でも true |
| fireDate | 0 | §3.4 の 4 例 + 09:00 ちょうどはずらさない |
| Presenter オファー | 1 | シェア前 false。メインシェア後 true。再シェアでは増えない（既に true のまま） |
| Presenter オファー抑制 | 1 | セット 1 件 / consumed / グループ空 / 無効シェア |
| Presenter 消費 | 1 | dismiss と save 成功で Disk true、再起動相当の新 Presenter でも false 表示 |
| ShareResultButton Equatable | 1 | クロージャが違っても shareText/isEnabled が同じなら == |
| 許可プロンプト | 2 | 未払い 0 なら needsPrompt false。未払いあり・未プロンプト・メインシェアで true |
| プロンプト 1 回 | 2 | consume 後はシェアしても true に戻らない |
| sync 規則 | 2 | Spy: 未払い 2 で schedule(2)。0 で cancel。許可前は schedule 0 回 |
| 精算 | 2 | 精算後 cancel（または sync(0)） |
| チェックは非計算 | 2 | トグル後も計算回数不変。sync だけ走る |
| 履歴 upsert | 3 | background 2 回（同一 ID）で count 1。済キーだけ更新 |
| 精算で増える | 3 | 別会計（initial 後の新規 ID）を保存すると count 2 |
| 続ける | 3 | 総額・済が戻り計算 1 回 |
| 同じ編成 | 3 | 総額空、済空、端数とグループ一致、計算 1 回 |
| 削除 | 3 | 件数 -1。lastBill は残る |
| 上限 | 3 | 6 回違う ID 列を save すると count 5、最古なし |
| 既存回帰 | 全期間 | Interactor / シェア文 / AdEligibility / 精算ガード / 回収席 ID / 広告オフ |

手動:

1. 新規インストール。総額入力 → メインシェア。カードが出る。保存名が「いつもの飲み会」。保存後、Menu に 1 件。再起動してシェアしてもカードは出ない
2. 別の新規状態（consumed を消すか削除インストール）。カードを閉じる。再起動後出ない。Menu から保存はできる
3. 未払いがある状態でシェア。許可 Alert。あとで。設定に通知許可は増えない。再シェアで Alert なし
4. 許可する。OS ダイアログを許可。3 時間待たず、デバッグは `fireDate` を一時的に +1 分にしてよい（提出ビルドに残さない。残っていたら差し戻し）
5. 許可後に全員済。通知センターの pending が消える
6. 精算完了。全画面は現行どおり。pending なし
7. 宴会を 2 回精算。履歴 2 件。初期画面から「同じ編成で始める」で総額空。Undo で戻る
8. dirty な入力中に「続ける」で確認が出る。キャンセルで入力不変
9. キーボード中バナーなし。シェア前に全画面なし。オファー保存でも全画面なし
10. VoiceOver: カード閉じるにラベル。通知許可 Alert が読める

デバッグ用の +1 分は **マージしない**。手動 4 は実機の pending 確認（`UNUserNotificationCenter.current().pendingNotificationRequests` をデバッガで見る）で代替してよい。

---

## 8. 完了の定義

2.1.0 第4スライスの実装完了とは、次をすべて満たす状態を指す。

1. セット 0 件の初回メインシェア後にだけ編成オファーが出る。保存または閉じで再表示しない
2. 未払いがあるメインシェア後に、インストール 1 回だけ説明 Alert が出せる。許可時のみローカル通知 1 通を予約する。全員済・精算で消える。リモートは無い
3. 妥当な会計は lastBill に加え直近 5 件の履歴に残る。起動は initial。シートから続ける / 同じ編成ができる
4. 総額入力からメインシェアまでのタップ数は 2.0.0 と同じ
5. 計算 Interactor・初期グループ・シェア文・広告トリガーが第1〜UI スライスと同一
6. Presenter が `GoogleMobileAds` と `UserNotifications` を import しない
7. `BillSnapshot` schema は 2。古い lastBill が読める
8. 壊れた履歴 JSON で起動しても落ちない
9. README が 3 機能と「ローカル通知であり毎日の配信ではない」ことを説明している
10. `MARKETING_VERSION` が 2.1.0

---

## 9. リスクと移行方針

| リスク | 対策 |
| --- | --- |
| ShareLink タップがシートを潰す | simultaneousGesture。手動で LINE シートが開くことをフェーズ 1 完了条件にする |
| オファーと許可 Alert と保存名 Alert が重なる | 許可 Alert 優先。保存名はカードの保存タップ後だけ |
| 通知が毎晩来る | ID 固定 1 通。repeats false。未払い 0 で cancel |
| 深夜に飛ぶ | fireDate の 0–8 時シフトをテストで固定 |
| 履歴が lastBill と二重管理でずれる | upsert は `saveLastBill` 内部。Presenter から履歴だけ書く口を作らない |
| schema 3 にしたくなる | 禁止。日付は Entry |
| 実通知を CI が叩く | Scheduler テストは Spy。本物 Center はテスト禁止 |
| 巨大 PR | フェーズ 0→4。提出は 4 完了後 |
| 2.0.0 の Info.plist テストを先に 2.1.0 へ | フェーズ 4 まで版を上げない |
| オファーが毎回出てウザい | セット 0 かつ未消費の初回だけ。ゲーム文言禁止 |

ブランチ戦略（推奨）:

1. `feat/v21-retention-contracts`（フェーズ 0）
2. `feat/v21-member-set-offer`（フェーズ 1）
3. `feat/v21-unpaid-reminder`（フェーズ 2）
4. `feat/v21-bill-history`（フェーズ 3）
5. `feat/v21-docs-version`（フェーズ 4。`MARKETING_VERSION = 2.1.0`）

---

## 10. 実装時のレビュー用 grep

```text
import UserNotifications
```

許可ファイル: `UnpaidReminderScheduler.swift` のみ（そのテスト Double 以外）。Presenter / Store / View / Interactor に出たら差し戻す。

```text
import GoogleMobileAds
```

許可は v2.0.0 と同じ。App / `AdBannerView` / `AdsController` のみ。

```text
session.billHistory
session.memberSetOfferConsumed
session.didPromptUnpaidReminder
```

`BillSessionStore` 以外にリテラルがあったら差し戻す。

```text
currentSchemaVersion = 3
oldestReadableSchemaVersion
```

Snapshot を 3 に上げていたら差し戻す。

```text
didPerformMainShare
```

未払い再シェア経路から呼ばない。

```text
addingTimeInterval
```

発火時刻の +3 時間は `UnpaidReminderSchedule` にだけ置く。View に魔法数を置かない。3 時間は `UnpaidReminderSchedule.delay` として定数化する。

```text
MARKETING_VERSION
CFBundleShortVersionString
```

フェーズ 4 完了後は 2.1.0。2.4.0 や 2.0.0 のままだったら差し戻す。

```text
NSUserTrackingUsageDescription
NSUserNotificationsUsageDescription
```

どちらも Info.plist に無いまま。

デバッグ用の短い発火間隔（1 分など）が残っていたら差し戻す。

---

## 11. Store 提出

提出は **2.1.0**。ショットは次を足してよい（必須は 2.0.0 ショットの更新判断に任せる）。

1. 回収ボード先頭の編成オファー
2. 履歴シート（2 件以上）

App Store Connect のプライバシー:

- データ収集の追加は原則なし（アカウントなし、通知内容は端末内）
- プッシュ通知の質問には **ローカル通知のみ** と明記する。サーバー送信はしない

提出作業（ショット撮影、プライバシーラベルのクリック操作）は実装フェーズに含めない。実装者は README と版番号まで。

---

## 12. この次（2.1.0 出荷後・実装しない）

| 順 | 候補 | 理由 |
| --- | --- | --- |
| 1 | IAP 買い切り（広告オフ永続 + セット無制限） | 戻る理由（オファー・通知・履歴）が揃ってから |
| 2 | ホーム画面ウィジェット | 未払いが古くなる。通知の効果を見てから |
| 3 | 端数の四捨五入 / 切り上げ | 計算仕様。テスト先行 |
| 4 | 席の個人名 | 今回の席 ID の上に名前を載せる |
| 5 | シェア画像 / OCR / 複数店舗 / ルーレット | 権限・別画面 |

---

## 13. 次のアクション

実装者は **このファイルのフェーズ 0 から** 始める。第1〜UI スライスの計画はやり直さない。v2.1.0 計画書（第2スライス）の「履歴一覧は 2.0.0 禁止」は、**本ファイルが 2.1.0 として上書きする**。

最初の実装コミットは `BillHistoryEntry` と `UnpaidReminderSchedule` のテストとする。View はフェーズ 1 から変える。通知の本物はフェーズ 2。版番号はフェーズ 4。

---

## 14. 実施記録

- フェーズ 0: `BillHistoryEntry` / Store 履歴と Bool / `UnpaidReminderSchedule` / xcstrings
- フェーズ 1: 編成オファー（メインシェア検知・カード・消費）
- フェーズ 2: 未払いローカル通知（Scheduler・許可 Alert・sync）
- フェーズ 3: 直近 5 件の履歴シート
- フェーズ 4: README と `MARKETING_VERSION = 2.1.0`
