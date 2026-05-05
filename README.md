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
- **Architecture**: **VIPER** (View, Interactor, Presenter, Entity, Router)
- **Unit Testing**: XCTest

## アーキテクチャのこだわり
本作では、スケーラビリティとテスト容易性を確保するため、**VIPERアーキテクチャ**を採用しています。

- **Interactor**: 複雑な割り勘の計算ロジックをカプセル化し、純粋なビジネスロジックとして独立させています。
- **Presenter**: `ObservableObject` としてViewの状態を管理し、Interactorとの橋渡しを担います。
- **Router**: モジュールの依存関係を注入（Dependency Injection）し、各部品を組み立てます。

## 品質担保
`SakuttoSplitTests.swift` において、`XCTest` を用いたロジックテストを実装しています。
- 基本的な均等割りのテスト
- 固定額と割合が混合した複雑なパターンの計算精度テスト
- 端数処理（切り捨て）および不足金の算出テスト

## スクリーンショット
| 入力画面 | 計算結果とシェア |
| --- | --- |
| <img width="1206" height="2622" alt="output" src="https://github.com/user-attachments/assets/c3da3e5a-9ef9-418c-8f72-0ce275ade20c" /> | <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-05-05 at 22 13 20" src="https://github.com/user-attachments/assets/4cd23f1f-0df8-421f-9661-64961945e8df" />

## 開発者
- mw-wakkun
