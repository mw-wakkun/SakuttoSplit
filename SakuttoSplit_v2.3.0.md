# SakuttoSplit v2.3.0 UI 改善 実装計画書

- 対象: 現行の単一 VIPER モジュール `Modules/SakuttoSplit` の View / Presenter chrome。計算・永続化スキーマ・広告 SDK は触らない
- 作成日: 2026-09-15
- 前提: 第1スライス（広告、`SakuttoSplit_v2.0.0.md`）・第2スライス（会計継続、`SakuttoSplit_v2.1.0.md`）・第3スライス（回収ボード、`SakuttoSplit_v2.2.0.md`）は完了済み
- 入力: 2026-09-15 の HIG レビュー（起動からシェアまでの手数削減とブランド色の固定）。採用範囲は本ファイル §2 に固定する
- 方針: **この文書ではコード実装を行わない**。実装者が迷わないよう、仕様・責務・手順・完了条件だけを固定する
- 評価観点: 総額入力からメインシェアまでのタップ数を減らす / 計算ロジックを変えない / 広告ルールと前回会計の保存点を壊さない / VIPER の境界を壊さない / 初期グループ（部長・一般）を変えない

**Store リリースは 2.0.0 にまとめる。** 本スライスを 2.3.0 として分けて出さない。`MARKETING_VERSION` はすでに 2.0.0 なので、**上げない**（2.1.0 / 2.3.0 にもしない）。2.0.0 をすでに提出済みのときだけ、リリース判断は本計画の外とする。

目的は、画面を「設定アプリ風の Form」から「会計の一枚」に変え、**シェアまでの手数を減らし、数字と Accent でブランドを立てる**ことである。IAP・OCR・席の個人名・シェア画像は範囲外。

---

## 0. なぜこれを次にするか

2.0.0 には広告・前回会計・回収ボードが揃っている。現場に残っているのは、機能ではなく **到達コストと見た目** である。

| 起きること | 現場 |
| --- | --- |
| いつもの部長/一般で総額だけ入れる | 総額タップ → 入力 → 完了 → スクロール → 緑シェア。3 タップ + スクロール |
| 起動はいつも initial | 前回の続きは左上の長いラベル。発見コストが高い |
| 主 CTA が `Color.green`、Accent 未設定 | 余剰金の意味色と衝突。スクリーンショットが他アプリと並ぶと識別できない |
| 端数 Picker と割合/固定が常時 | 八割の宴会で触らない制御が、結果とシェアを画面外へ押し出す |
| 編成の保存/読込がグループ節の末尾 | 結果の直前に 2 行。適用のたびに Alert |
| 回収が Toggle、精算は無確認 | スイッチは設定用。破壊的な精算だけ確認がない |

第1〜3スライスの「シェアまでのタップ数を増やさない」は達成済みである。本スライスは **同じ契約を保ったまま、その手数を減らす**。

---

## 1. 現状サマリ（第3スライス完了後）

| 項目 | 現状 |
| --- | --- |
| 画面 | `NavigationStack` + `Form` 3 セクション。シェアは結果節の緑全幅。バナーは Form 外 |
| 起動 | 常に `SakuttoSplitViewState.initial`。総額は空。オートフォーカスなし |
| 復元 | `hasLastBill` のとき左上 `session.restore`。initial なら確認なし、dirty なら Alert |
| 編成 | グループ節に保存/読込。シートの副次行はグループ件数だけ。適用は Alert |
| グループ行 | Form 内 `roundedBorder` + 常時ゴミ箱 + segmented 常時 |
| 端数 | お会計設定に 5 値 Picker 常時。既定 `.hundred` |
| 主 CTA | `ShareResultButton`。`Color.green` + `message.fill` + `listRowBackground` |
| 広告オフ | 右上 `video.slash` |
| 回収 | 結果節の入れ子 `Section`。席は `Toggle`。グループ一括なし |
| 精算 | `.bordered`。確認なし。成功直後にインタースティシャル |
| シェア文 | 絵文字つき。金額はカンマなし |
| Accent | `AccentColor.colorset` が universal 空。システム青 |
| 計算 | Interactor 純関数。1 Intent = 1 計算。変更しない |
| アプリ版 | `MARKETING_VERSION = 2.0.0` |

---

## 2. プロダクト方針（先に決めること）

実装中にひっくり返さない。

### 2.1 採用する

| 判断 | 理由 |
| --- | --- |
| 総額をヒーロー数字にする | 「サクッと」の記憶色は金額。設定行のプレースホルダではブランドにならない |
| メインシェアを Form の外、バナー直上へ固定する | スクロールしないと押せない主操作をやめる。全幅・headline は維持 |
| 色は Accent。`Color.green` は主 CTA から外す | 余剰/不足だけ semantic 緑/赤。ブランド色と意味色を分ける |
| 起動時、総額空かつ VoiceOver オフなら総額へフォーカス | 最初のタップを消す。VO 中はフォーカスを奪わない |
| 前回会計カードは **initial かつ lastBill あり** のときだけ | 自動復元はしない（第2スライス契約）。入口を 1 タップのカードにする |
| 左上復元は **dirty かつ lastBill あり** のときだけ | initial ではカードと二重にしない |
| 端数はディスクロージャ。既定 100 円は変えない | プログレッシブディスクロージャ |
| グループ行は名前・人数を常時。モードは折りたたみ | 部長/一般の初期 2 件は残す。差別化を消さない |
| 編成の保存/読込と広告オフは trailing `Menu` | グループ節から 2 行を外し、結果を上げる |
| 編成の適用は即時 + Undo バナー | 破壊でない置換に Alert を使わない |
| 回収はチェックマーク。グループ「全員済」を 1 タップ | Toggle は設定用。タスク完了にはチェック |
| 精算完了の前に確認する | 無確認リセット + 全画面が、復元探しより高い事故 |
| キーボード中は sticky シェアを出さない。妥当なら toolbar にシェア | CTA の二重化と、キーボードに隠れるフッターを避ける |
| シェア文はレシート調（絵文字なし、カンマあり） | UI と LINE に貼った文面のトーンを揃える。情報項目は維持 |
| 金額の正本は数字文字列のまま。表示とシェア文だけ Formatter | `viewState.totalAmountText` と Snapshot を壊さない |

### 2.2 採用しない（本スライス / 2.0.0 禁止）

| 判断 | 理由 |
| --- | --- |
| 起動時の自動復元 | 新しい会計の開始を遅らせる。第2スライス禁止を踏襲 |
| 初期グループの変更・削除 | 部長 1 / 10,000・一般 4 / 1.0 は需要の証拠 |
| 均等割り専用モードや人数だけの画面 | ハイブリッド計算が商品。畳むのであって、入口を二系統にしない |
| Interactor・端数の四捨五入/切り上げ | 計算仕様。別計画 |
| IAP / OCR / 席の個人名 / シェア画像 / Live Activity | 第3スライス「この次」のまま |
| 未払い再シェアを accent 全幅にする | メインシェア専用。`.bordered` のまま |
| 精算・シェア・チェックでの全画面追加 | インタースティシャルは精算成功後のみ |
| キーボード中バナー | 第1スライス契約 |
| schema 3 / lastBill キー変更 | 表示用 preview は chrome に載せる。Disk の形は変えない |
| Material 風スナックバー・独自トーストデザイン | Undo は短いバナー + ボタン。色はシステム |
| `Color.green` のまま「ブランド緑」と呼ぶこと | iOS の success と衝突する |

### 2.3 UX の絶対ルール

実装者が迷ったら、ここに戻る。**第1〜3スライスの絶対ルールのうち、本スライスが上書きするものだけを明示する。**

1. 総額入力からメインシェアまでのタップ数は、今より増やさない。目標はキーボード入力を除き **1**（フォーカス済みなら入力 → シェア）
2. 起動は initial。自動復元しない
3. 1 人あたり金額の上に広告も編成 UI もバナーも置かない
4. メインシェアは 1 つ。全幅・headline。色は **Accent**（v2.0.0 の「緑」は破棄）
5. 未払い再シェアは `.bordered`。精算完了も `.bordered`
6. 全画面は精算確認を経た **成功後** だけ。確認キャンセルでは出さない
7. キーボード中にバナーが見えない。キーボード中に sticky シェアも見えない
8. 計算式・初期グループは変えない。シェア文の **項目**（総額・1人あたり・過不足・送金依頼）は変えるが、欠かさない
9. 回収ボードは妥当な入力のときだけ。席展開規則（20 以下展開、21 以上 1 行）は不変
10. Presenter は GoogleMobileAds を import しない

v2.2.0 の「ボードはシェアボタンの下」は、シェアが Form 外へ出るため次に読み替える。

- 結果数字 → 回収ボード → 精算完了、の順は Form 内で維持する
- メインシェアは Form 外 sticky。数字と sticky の間にボードが来てよい（主 CTA が画面下に常駐するため）

---

## 3. 仕様

### 3.1 用語

| 用語 | 意味 |
| --- | --- |
| ヒーロー総額 | お会計設定の先頭。`.largeTitle` + 表形式数字 + `円` |
| sticky シェア | Form 外、バナー直上のメイン `ShareLink` |
| 再開カード | initial かつ lastBill ありのとき、ヒーロー総額の上に出す 1 タップ復元 |
| 詳細 Menu | 右上 `ellipsis.circle`。編成の保存/読込と広告オフ |
| Undo バナー | 編成適用直後の短い取り消し。Alert ではない |
| レシート文面 | 絵文字なし、カンマありのメイン / 未払いシェア文 |

### 3.2 画面階層（完成形）

```text
VStack(spacing: 0)
  NavigationStack
    Form
      Section お会計設定
        再開カード（条件つき）
        ヒーロー総額
        端数（navigationLink / ディスクロージャ）
      Section 参加者グループ
        グループ行（追加。保存/読込ボタンは置かない）
      Section 計算結果
        結果行 / 過不足 / バリデーション
        （シェアを置かない）
      Section 回収（seats が空でなければ）
        席チェック / 進捗 / 未払い再シェア
      精算完了行
    toolbar leading: 復元（dirty かつ hasLastBill）
    toolbar trailing: Menu
    toolbar keyboard: 次へ or シェア / 完了
  sticky シェア（フォーカスなしのときだけ）
  バナースロット（現行 AdBannerSlot）
```

`CollectionSection` は **自分で `Section` を開かない**。入れ子見出しをやめる。

### 3.3 ブランド色

`Assets.xcassets/AccentColor.colorset` に値を入れる。universal 空のままにしない。

| 外観 | sRGB |
| --- | --- |
| Light | `0.769, 0.353, 0.102`（`#C45A1A`） |
| Dark | `0.878, 0.541, 0.235`（`#E08A3C`） |

Any Appearance は Light を使う。P3 は必須にしない。

使用:

| 面 | 色 |
| --- | --- |
| sticky シェアの背景 | `Color.accentColor` |
| シェア上のラベル | 白（`.white`）。Dark でも白 |
| 余剰金 | 現行どおり semantic `.green` |
| 不足金 | 現行どおり semantic `.red` |
| 未払い再シェア / 精算 | `.bordered`。accent 全幅にしない |
| 削除 | 現行どおり destructive |

`ShareResultButton` から `listRowBackground(Color.green)` を削除する。Form 外になるため、背景はボタン自身が持つ。

### 3.4 ヒーロー総額とオートフォーカス

- `viewState.totalAmountText` は数字のみ。Formatter は表示専用
- 非フォーカス時: 空ならプレースホルダ `total_amount.placeholder`（`例: 35,000`）。値ありならグループ化した数字
- フォーカス時: 入力中は数字のみでよい（既存 `BoundedIntegerField`）。グループ化のライブ更新は必須にしない
- フォント: `.largeTitle`、`.monospacedDigit()`、Dynamic Type。幅不足は `minimumScaleFactor(0.5)` + 1 行
- 単位 `unit.yen` はフィールド右。現行と同じ

オートフォーカス:

1. 初回 `onAppear` で `totalAmountText.isEmpty` かつ `!UIAccessibility.isVoiceOverRunning` なら `focusedField = .totalAmount`
2. 精算成功後（確認を経て `didTapSettleComplete` したあと）も同様に総額へフォーカス
3. 復元後はフォーカスしない（カード/左上から戻した金額を読む）
4. 編成適用後はフォーカスしない

### 3.5 再開カードと左上復元

Presenter が `sessionChrome.lastBillPreview` を公開する。Store の JSON 形は変えない。

```text
struct LastBillPreview: Equatable {
  var totalAmountText: String          // 正本の数字文字列
  var unpaidCount: Int
  var seatCount: Int
}
```

算出: `sessionStore.lastBill` があるときだけ。席数は Snapshot の groups + `InputLimits.collectionExpandMaxCount` で `CollectionSeat.make` 相当。`unpaidCount = seatCount - paidSeatKeys のうち現存席`。妥当な lastBill だけが Store に入る前提。

| 状態 | 再開カード | 左上復元 |
| --- | --- | --- |
| lastBill なし | 出さない | 出さない |
| lastBill あり、かつ現在が initial | 出す | 出さない |
| lastBill あり、現在が dirty | 出さない | 出す |

カードタップ: `didTapRestoreLastBill()`。initial なので `needsRestoreConfirmation == false`。確認 Alert は出さない。

左上: 現行どおり dirty なら確認 Alert。コピーは現行キーのまま。

カード表示:

- タイトル `session.resume_card_title` = `前回の会計を続ける`
- 詳細は総額（表示フォーマット）と `session.resume_card_unpaid %lld %lld` = `未払い %lld / %lld`
- 席 0（保存時にボード非対象だった古いデータは unpaid/seat が 0）のときは総額だけ出し、未払い行を出さない

### 3.6 端数

`RoundingUnitPicker` は Form 内のディスクロージャ（`.pickerStyle(.navigationLink)` または同等）。常時ホイール/インライン 5 段にしない。

既定 `.hundred`、choices は現行 1 / 10 / 100 / 500 / 1000 円。計算は変えない。

### 3.7 グループ行

常時:

- グループ名 `TextField`（**Form 標準。`.roundedBorder` を外す**）
- `CountStepper`

常時出さない:

- 赤いゴミ箱ボタン。削除は `ForEach` の `onDelete` / swipe
- 折りたたみ中の segmented

折りたたみ時の 1 行キャプション（タップで展開）:

- 固定: `payment_mode.fixed` + 金額（表示フォーマット）+ `円`
- 割り勘: `payment_mode.ratio` + 倍率 + `倍`

展開時: 現行の segmented + 固定額/倍率フィールド。

展開状態は View の行ローカル `@State`。Presenter に持たない。再描画で閉じてもよい。

segmented の表示文字列:

| キー | 新 value |
| --- | --- |
| `payment_mode.ratio` | `割り勘`（旧: 割合） |
| `payment_mode.fixed` | `固定`（旧: 固定額） |

プレースホルダ `group.fixed_amount_placeholder` / `group.ratio_placeholder` は現行のまま。

削除:

- View は swipe を全行に出してよい
- 最後の 1 件を swipe で消すと `validation.no_groups` になる契約は **Presenter として残す**（既存テストを残す）
- 常時ゴミ箱アイコンは置かない

「グループを追加」は現行。保存/読込ボタンはこのセクションから削除する。

### 3.8 詳細 Menu（右上）

ラベル: `Image(systemName: "ellipsis.circle")`。`accessibilityLabel` = `menu.more`（value: `メニュー`）。

```text
Menu
  Section
    この編成を保存     → 現行 saveMemberSetTapped()
    保存した編成を使う → 現行 didTapOpenMemberSetSheet()
  Section
    広告オフ中なら残り時間テキスト（disabled）
    そうでなければ「今日の広告をオフ」→ 現行 hideAdsForToday()
```

保存の空き枠・リワード・上限 Alert は現行ロジックのまま。入口が Menu に移るだけ。

`video.slash` の単独 toolbar ボタンは削除する。

### 3.9 メンバーセットシートと適用 Undo

シート行の副次テキスト:

```text
"{name} {count}" を " / " で連結 + " · {roundingUnit}円"
例: 部長 1 / 一般 4 · 100円
```

グループ 0 件のセットは保存できない（現行）。空シートは現行 `set.empty`。

適用:

1. シートを閉じる
2. **確認 Alert を出さない**
3. `didTapApplyMemberSet(id:)` が、適用前の `groups` + `roundingUnit` を Undo として保持してから置き換える
4. 総額は維持。席は作り直し（すべて未払い）。計算 1 回（現行）
5. 画面に Undo バナーを出す

Undo:

- 文言: タイトル相当 `set.applied` = `編成を適用しました`、ボタン `set.undo` = `取り消す`
- 表示: ナビ直下または Form 上端の 1 行。システム背景。4 秒で消える（View のタイマー）
- `didTapUndoMemberSetApply()` で適用前の groups + roundingUnit に戻す。総額は維持。席は作り直し。計算 1 回
- 次の `applyUpdate`（入力変更・グループ増減・端数・別セット適用・精算・復元）で Undo は捨てる
- バナーが消えても、次の `applyUpdate` までは Intent として残してよい。バナー非表示後に toolbar から取り消す入口は作らない
- `needsMemberSetApplyConfirmation` は **プロトコルから削除**

削除確認 Alert（スワイプ）は現行のまま。

### 3.10 sticky シェアとキーボード

`ShareResultButton` は結果セクションから外す。親 `VStack` でバナーの直上。

| 条件 | sticky | キーボード toolbar |
| --- | --- | --- |
| いずれかのフィールドがフォーカス | 出さない（高さ 0） | 右: 妥当ならシェア、でなければ「次へ」。常に「完了」 |
| フォーカスなし | 出す（disabled でも位置は維持） | なし |

有効条件は現行 `validationIssue == nil`。disabled 時 opacity 0.45。

見た目:

- `Label("share.button", systemImage: "square.and.arrow.up")`（`message.fill` をやめる）
- `.font(.headline)`、白文字、accent 背景、全幅、縦 padding は現行程度
- `ShareLink` を `.equatable()` で包まない制約は、Form の `listRowBackground` を使わなくなるため **解除してよい**。包んでも色が落ちないことを Preview で確認する

キーボード「次へ」の順:

1. 総額 → 先頭グループの名前
2. グループ名 → 同じグループの人数
3. 人数 → 同じグループが展開中なら固定額/倍率。閉じていれば次グループの名前
4. 固定額/倍率 → 次グループの名前。最後ならフォーカス解除
5. 次グループが無ければフォーカス解除

「完了」は現行どおり全フォーカス解除。バナー規則（フォーカス中は高さ 0）は変えない。

精算成功後のオートフォーカス中はバナーが畳まれる。それは第1スライスどおり正しい。

### 3.11 計算結果・回収・精算

計算結果セクション:

1. 結果行（現行。1 人あたり金額は表示フォーマット）
2. 過不足（現行色）
3. バリデーション（現行）
4. **シェアは置かない**

回収セクション（兄弟 `Section`、`validationIssue == nil` で seats があるときだけ）:

- 席行: **Toggle を使わない**。チェックは `checkmark.circle.fill` / `circle` のボタン。ラベルと 1 人あたり金額は現行
- 同一 `groupID` の席が 2 以上あるとき、そのブロックの先頭または末尾に `collection.mark_group_paid` = `全員済`。1 席だけのグループ（21 人以上の 1 行を含む）には出さない
- 進捗は `ProgressView` + 現行 `collection.progress` / `collection.all_paid`
- 未払い `ShareLink` は `.bordered` のまま。緑/accent 全幅にしない

`didTapMarkGroupCollectionPaid(groupID:)`:

- その `groupID` の席をすべて `isPaid = true`
- 計算しない（トグルと同じ）
- すでに全員済なら no-op

Haptic（View のみ。テストしない）:

- 席の個別チェック: `UIImpactFeedbackGenerator(style: .light)`
- 全員済になった瞬間（個別でも一括でも）: `UINotificationFeedbackGenerator` `.success`
- VoiceOver / Reduce Motion でも出してよい。システムの触覚オフに従う

精算完了:

- 位置は回収の下（ボード非表示なら結果の下）
- タップで `confirmationDialog`（または Alert）。**Presenter はまだ呼ばない**
- 実行で現行 `settleComplete()`（フォーカス解除 → `didTapSettleComplete` → インタースティシャル）
- キャンセルでは広告もリセットも出さない

コピー:

| キー | value |
| --- | --- |
| `settle.confirm_title` | `次の会計に進みますか？` |
| `settle.confirm_message` | `今夜の内容は前回の会計として残し、入力を初期状態に戻します。` |
| 実行ボタン | 現行 `settle.complete` |
| キャンセル | システム Cancel |

確認 UI に広告の話は書かない。

### 3.12 金額表示とシェア文

共通 Formatter（新ファイル `Config/YenFormatting.swift` 想定）:

- ロケール `ja_JP`
- 整数、grouping separator あり
- 符号なし。負値は過不足側で `abs` 済みを渡す
- `viewState` / Snapshot / 入力正規化は **数字文字列のまま**

メインシェア（`ShareTextBuilder.build`。項目順は維持、トーンだけ替える）:

```text
本日のお会計
総額  35,000円
----------------
部長  1人 10,000円
一般  1人 6,200円
----------------
不足  200円
PayPay等で送金をお願いします
```

余剰のときは `不足` を `余剰` にする。絵文字・「金」接尾・「※」「！」は付けない。

未払い:

```text
未払いのお願い
総額  35,000円
----------------
一般 2  1人 6,200円
一般 4  1人 6,200円
----------------
PayPay等で送金をお願いします
```

空席配列は現行どおり空文字。

`ShareTextBuilderTests` と Presenter テスト内の期待文字列は **本スライスで更新する**。第3スライスの「メイン文面テストを変えない」は、本スライスが明示的に上書きする。

### 3.13 ローカライズ（追加・変更キー）

追加:

| キー | value |
| --- | --- |
| `menu.more` | `メニュー` |
| `session.resume_card_title` | `前回の会計を続ける` |
| `session.resume_card_unpaid %lld %lld` | `未払い %lld / %lld` |
| `set.applied` | `編成を適用しました` |
| `set.undo` | `取り消す` |
| `collection.mark_group_paid` | `全員済` |
| `settle.confirm_title` | `次の会計に進みますか？` |
| `settle.confirm_message` | `今夜の内容は前回の会計として残し、入力を初期状態に戻します。` |
| `action.next` | `次へ` |

変更:

| キー | 新 value |
| --- | --- |
| `total_amount.placeholder` | `例: 35,000` |
| `payment_mode.ratio` | `割り勘` |
| `payment_mode.fixed` | `固定` |
| `share.button` | 現行 `結果をLINE等でシェア` のまま |

既存の復元確認・編成保存名・広告オフ・回収進捗・精算ボタンラベルは変えない。

### 3.14 触らないもの（再掲）

- `SakuttoSplitInteractor` の計算式と端数切り捨て
- `SakuttoSplitViewState.initial` のグループ
- バナー規則・インタースティシャル資格・リワード目的の分離
- `BillSnapshot` schema と `paidSeatKeys`
- メンバーセット枠 1...3 とリワード追加
- 本番広告ユニット ID / `GADApplicationIdentifier`
- `MARKETING_VERSION`（2.0.0 のまま）
- GoogleMobileAds の import 許可リスト（App / `AdBannerView` / `AdsController` のみ）

---

## 4. アーキテクチャ

View は描画と Intent 転送だけ。判断は Presenter。広告 SDK は View が `AdsController` に依頼する現行のまま。

```text
Presenter
  @Published viewState          … 現行。計算の正本。数字文字列
  @Published sessionChrome      … lastBillPreview を追加
  @Published collectionState    … 現行。didTapMarkGroupCollectionPaid を追加
  memberSetUndo                 … 非 Published でよい。適用前の groups + roundingUnit

didTapApplyMemberSet
  undo を積んでから現行の置き換え

didTapUndoMemberSetApply
  undo があれば applyUpdate で戻し、undo を捨てる

applyUpdate
  通常経路では memberSetUndo を捨てる（Undo Intent 自身は捨てない）

makeSessionChrome
  lastBill から LastBillPreview を載せる
```

### 4.1 責務

| 層 | 内容 |
| --- | --- |
| Config | `YenFormatting`。Presenter / View / ShareTextBuilder が使う |
| Entity | `LastBillPreview` は chrome 側でよい。CollectionSeat の展開規則は変えない |
| Interactor | **変更しない** |
| Presenter | preview、Undo、グループ全員済。計算式は触らない |
| View | 階層、フォーカス、Menu、確認、Undo バナー、haptic、チェック UI |
| Ads | **変更しない**（入口が Menu に移るだけ） |
| Store | **変更しない** |

### 4.2 ファイル配置（予定）

| ファイル | 役割 |
| --- | --- |
| `Config/YenFormatting.swift`（新設） | 整数 → `35,000` |
| `Assets.xcassets/AccentColor.colorset` | Light / Dark の値 |
| `Presenter/ShareTextBuilder.swift` | レシート文面。Formatter を使う |
| `Presenter/SakuttoSplitSessionChrome.swift` | `lastBillPreview` |
| `Presenter/SakuttoSplitPresenter.swift` | preview / Undo / 全員済 |
| `Contract/SakuttoSplitContract.swift` | 確認プロパティ削除、Intent 追加 |
| `View/SakuttoSplitView.swift` | 階層、Menu、sticky、キーボード、確認、オートフォーカス |
| `View/Subviews/TotalAmountSection.swift` | ヒーロー数字 |
| `View/Subviews/RoundingUnitPicker.swift` | ディスクロージャ |
| `View/Subviews/GroupRowView.swift` | クロム削減、折りたたみ |
| `View/Subviews/GroupListSection.swift` | 保存/読込削除、swipe 削除 |
| `View/Subviews/ShareResultButton.swift` | accent、共有アイコン、Form 外前提 |
| `View/Subviews/CalculationResultSection.swift` | シェアと回収を外す |
| `View/Subviews/CollectionSection.swift` | `Section` を外す。チェック。全員済 |
| `View/Subviews/MemberSetSheet.swift` | 副次行の編成プレビュー |
| `View/Subviews/SettleCompleteButton.swift` | 見た目は現行。確認は親 |
| `Localizable.xcstrings` | §3.13 |
| `README.md` | 画面の説明を 1 節で更新 |

Preview は触ったサブビューに、ヒーロー / 再開カードあり / 回収チェック / sticky disabled を足す。

---

## 5. フェーズ

フェーズごとに PR を切る。計算期待値と見た目を混ぜない。**画面はフェーズ 1 から変えてよいが、フェーズ 0 のテストが先に Red で固定されていること。**

### フェーズ 0: 契約とテスト先書き

目的: 文面・preview・Undo・全員済を UI なしで固定する。

実施内容:

1. `YenFormatting`（0、35000、6、10000）
2. `ShareTextBuilder` の新期待値（メイン不足/余剰、未払い、空）
3. `lastBillPreview`: lastBill なしは nil。部長1+一般4・済 2 席なら unpaid 3 / seat 5
4. 編成適用で Undo が残り、Undo で groups + rounding が戻る。総額は変わらない。適用は計算 1 回、Undo は計算 1 回
5. 適用後に総額変更すると Undo は捨てる
6. `didTapMarkGroupCollectionPaid` は spy 計算 0 回。対象グループだけ済
7. `needsMemberSetApplyConfirmation` を契約から外すテストへ書き換え

完了条件:

- 既存 Interactor / 広告資格 / schema 1 互換はグリーン
- 画面はまだ変えていなくてよい（このフェーズで View を触らない）

### フェーズ 1: Accent・sticky シェア・キーボード・オートフォーカス

目的: 手数の P0。ブランド色を最初に立てる。

実施内容:

1. AccentColor の値
2. `ShareResultButton` を結果節から外し、バナー直上へ。`Color.green` / `message.fill` / `listRowBackground` を削除
3. フォーカス中は sticky を出さない
4. キーボード: 妥当ならシェア、`action.next`、完了
5. 総額空の appear と精算成功後のオートフォーカス（VO 中はしない）
6. 広告オフの単独ボタンをやめ、暫定でも trailing Menu に載せてもよい（フェーズ 2 で編成と合流）

完了条件:

- キーボード中バナー高さ 0 のテストがグリーン
- 妥当な入力で、スクロールなしにシェアできる（手動）
- 未払い再シェアが accent 全幅になっていない

### フェーズ 2: 再開カードと復元入口の分割

目的: 前回の続きを 1 タップにする。自動復元はしない。

実施内容:

1. 再開カード UI と `lastBillPreview` の接続
2. 左上復元は dirty のときだけ
3. ヒーロー総額（プレースホルダ変更、非フォーカス時のカンマ）

完了条件:

- 起動は initial。カードを押すまで lastBill を入力へ流さない
- initial でカードと左上が同時に出ない
- dirty の左上は現行 Alert

### フェーズ 3: グループの畳み込みと編成 Menu

目的: 結果を上げ、Alert を減らす。

実施内容:

1. 端数ディスクロージャ
2. グループ行の標準 TextField、ゴミ箱削除、モード折りたたみ、swipe 削除
3. グループ節から保存/読込ボタンを削除
4. trailing Menu に保存/読込/広告オフを集約
5. シート副次行プレビュー
6. 適用 Alert 削除、Undo バナー

完了条件:

- 初期 2 グループの値は initial のまま
- 適用で確認 Alert が出ない
- 広告オフの報酬（24h）と編成枠リワードが混ざらない

### フェーズ 4: 回収チェック・精算確認・結果の入れ子解消

目的: HIG のコントロールと破壊的操作。

実施内容:

1. `CalculationResultSection` から回収を外し、Form の兄弟セクションへ
2. Toggle → チェック。`全員済`。ProgressView。haptic
3. 精算の confirmationDialog
4. 結果行のカンマ表示

完了条件:

- トグル経路の計算 0 回テストが、チェックと全員済でも 0 回
- 精算キャンセル後に state が initial でない、広告 present が呼ばれない（View の呼び出し順。Presenter テストは現行で可）
- 入れ子 `Section` がない

### フェーズ 5: 仕上げ

目的: 2.0.0 に載せる。

実施内容:

1. README の画面説明（ヒーロー総額、sticky シェア、再開カード、Menu）を短く更新
2. `MARKETING_VERSION` は **2.0.0 のまま**
3. Preview と手動チェックリスト
4. `🍻` が本番コードとテスト期待値から消えていること（Preview のダミーもレシート調に）

完了条件:

- セクション 8 を満たす

---

## 6. ファイル別対応マップ

| 現状 | 変更 | フェーズ |
| --- | --- | --- |
| シェア文が絵文字 | レシート + `YenFormatting` | 0 |
| chrome に preview なし | `lastBillPreview` | 0 |
| 適用確認プロパティ | 削除し Undo Intent | 0 |
| 回収に一括なし | `didTapMarkGroupCollectionPaid` | 0 |
| Accent 空、CTA が緑 | 色と sticky | 1 |
| キーボードは完了のみ | 次へ / シェア | 1 |
| 復元が左上のみ | カード分割 | 2 |
| 総額が title2 | ヒーロー | 2 |
| 端数常時、グループが dense | 畳む | 3 |
| 保存/読込が Form 内 | Menu | 3 |
| 回収が入れ子 Toggle | 兄弟セクション + チェック | 4 |
| 精算が無確認 | confirmationDialog | 4 |
| README が旧画面 | 更新 | 5 |

---

## 7. テスト計画

| 対象 | フェーズ | 内容 |
| --- | --- | --- |
| YenFormatting | 0 | 0 → `0`、35000 → `35,000`、6200 → `6,200` |
| ShareTextBuilder メイン | 0 | §3.12 の不足例。余剰は `余剰`。絵文字なし |
| ShareTextBuilder 未払い | 0 | 指定席のみ。空は `""` |
| lastBillPreview | 0 | nil / 件数 |
| Undo | 0 | 適用→Undo で groups 復帰。総額維持。計算回数 |
| Undo 破棄 | 0 | 適用後の総額変更で undo 不可 |
| 全員済 | 0 | 対象グループのみ。spy 0 |
| 既存 Presenter 精算 | 全期間 | 保存してから initial。確認 UI は View |
| 既存復元確認 | 2 以降 | initial では false。dirty では true |
| 既存バナー | 1 | フォーカス中 0。sticky の有無で AdBannerSlot を変えない |
| 既存メンバーセット枠 | 3 | 無料 1、上限 3、リワード目的分離 |
| 既存席展開 | 4 | 4 人 4 席、21 人 1 行 |
| Info.plist | 5 | `CFBundleShortVersionString == 2.0.0`、GAD ID 不変 |
| 既存 Interactor | 全期間 | 均等・混合・端数 |

手動:

1. 起動。VO オフなら総額キーボード。バナーなし。シェアは toolbar。完了後、sticky がバナー直上
2. 部長/一般のまま 35000。スクロールせずシェア。文面がレシート調。LINE にカンマがある
3. ホームへ。再起動は initial + 再開カード。カード 1 タップで金額と済が戻る。左上復元は出ない
4. 総額をいじるとカードが消え、左上復元が出る。確認 Alert は dirty のみ
5. Menu から編成を適用。Alert なし。Undo で戻る。総額は維持
6. 回収をチェック。スイッチ UI ではない。一般を全員済にできる。未払い再シェアは bordered
7. 精算を開きキャンセル。画面も広告も変わらない。実行すると initial +（15 秒後なら）全画面
8. キーボード中バナーなし。シェアやチェックでは全画面なし

---

## 8. 完了の定義

本スライスの完了とは、次をすべて満たす状態を指す。2.0.0 提出は本スライス込みで行う。

1. 総額空の起動で（VO オフなら）総額にフォーカスし、妥当入力後にスクロールなしでメインシェアできる
2. sticky シェアが accent 全幅。`Color.green` と `message.fill` が主 CTA にない
3. 起動は initial。lastBill があるとき再開カード 1 タップ。自動復元しない
4. 編成の保存/読込がグループ節にない。適用 Alert がなく Undo で戻せる
5. 回収が結果節の入れ子でない。チェック UI。グループ全員済がある。計算しない
6. 精算は確認後にだけリセットと全画面が出る
7. シェア文が §3.12。Interactor / schema / 広告 ID / バナー規則 / 初期グループが不変
8. `MARKETING_VERSION` が 2.0.0 のまま
9. README が新しい画面階層を説明している

---

## 9. リスクと移行方針

| リスク | 対策 |
| --- | --- |
| sticky + バナー + Home Indicator で結果が隠れる | シェア縦パディングを現行程度に抑える。Form はキーボード dismiss 現行。結果はスクロール可能 |
| キーボードと sticky の二重 CTA | フォーカス中は sticky 高さ 0 |
| オートフォーカスが VoiceOver を奪う | `isVoiceOverRunning` ならしない |
| シェア文変更で LINE の「いつもの文面」が変わる | 項目は維持。絵文字だけ落とす。本スライスでテストを明示更新 |
| Undo が Alert より発見しにくい | 適用直後 4 秒。誤適用の主経路をカバーする。永続の取り消し履歴は作らない |
| 精算確認でタップ +1 | 誤精算の復元探しより安い。キャンセルでは広告を出さない |
| `listRowBackground` 制約のコメントが残る | 使わなくなったらコメントと refactor 文書の参照を更新してよい |
| 巨大 PR | フェーズ 0→5 |

ブランチ戦略（推奨）:

1. `feat/v2-ux-contracts`（フェーズ 0）
2. `feat/v2-ux-sticky-share`（フェーズ 1）
3. `feat/v2-ux-resume-hero`（フェーズ 2）
4. `feat/v2-ux-groups-menu`（フェーズ 3）
5. `feat/v2-ux-collection-settle`（フェーズ 4）
6. `feat/v2-ux-docs`（フェーズ 5）

---

## 10. 実装時のレビュー用 grep

```text
Color.green
```

主 CTA に出たら差し戻す。過不足の `.green` / `.red` は可。

```text
message.fill
video.slash
listRowBackground
```

本スライス完了後の本番コードに残さない（テストの旧コメントも消す）。

```text
🍻
```

本番とテスト期待値から消す。

```text
needsMemberSetApplyConfirmation
```

完了後に残っていたら差し戻す。

```text
import GoogleMobileAds
```

許可は App / `AdBannerView` / `AdsController` のみ。

```text
applyUpdate
```

席トグルと全員済から呼ばない。

```text
MARKETING_VERSION
CFBundleShortVersionString
```

2.0.0 のまま。

---

## 11. Store 提出

広告・会計継続・回収・本スライスを **2.0.0 で一度だけ** 出す。版番号は上げない。

ショットは次を含める。

1. ヒーロー総額 + 再開カード（前回ありの初期画面）
2. 妥当入力後の sticky シェアと回収チェック（旧「緑行が Form の途中」ショットは捨てる）

提出作業（ショット撮影、プライバシーラベル）は実装フェーズに含めない。

---

## 12. この次（2.0.0 出荷後・実装しない）

継続率（編成オファー / 未払いローカル通知 / 会計履歴）は `SakuttoSplit_v2.4.0.md` を正とする。IAP はその後。

| 順 | 候補 | 理由 |
| --- | --- | --- |
| 1 | 継続率 3 点（`SakuttoSplit_v2.4.0.md`） | 閉じたあとに戻る理由がまだない |
| 2 | IAP 買い切り（広告オフ永続 + セット無制限） | 枠と 24h オフと回収と画面と継続導線が揃ってから |
| 3 | 端数の四捨五入 / 切り上げ | 計算仕様。テスト先行 |
| 4 | 席の個人名 | 今回の席 ID の上に名前を載せる |
| 5 | シェア画像 | レシート調文面の延長。デザインが大きい |
| 6 | OCR / 複数店舗 / ルーレット | 権限・別画面 |

---

## 13. 次のアクション

実装者は **このファイルのフェーズ 0 から** 始める。第1〜3スライスの計画はやり直さない。v2.0.0 の「シェアは緑」と v2.2.0 の「メイン文面テストを変えない」は、**本ファイル §2.3 / §3.12 が上書きする**。

最初の実装コミットは `YenFormatting` とレシート文面のテストとする。View はフェーズ 1 から変える。

---

## 14. 実施記録

- 2026-09-15: **フェーズ 0〜4 完了**。契約とテスト先書き、Accent / sticky シェア / キーボード、再開カードとヒーロー総額、グループ畳み込みと Menu、回収チェックと精算確認。
- 2026-09-15: **フェーズ 5 完了**。README に画面階層と提出前の目視を追記。`MARKETING_VERSION = 2.0.0`。`🍻` をテストダミーと Preview から削除。実機の目視は提出前に行う。
