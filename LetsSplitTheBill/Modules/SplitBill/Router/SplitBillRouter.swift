//
//  SplitBillRouter.swift
//  LetsSplitTheBill
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// VIPERの各部品を初期化して繋ぎ合わせる（組み立てる）クラス
class SplitBillRouter {
    
    static func assembleModule() -> AnyView {
        // 1. Interactor（計算職人）を作る
        let interactor = SplitBillInteractor()
        // 2. Presenter（現場監督）を作り、Interactorを渡す
        let presenter = SplitBillPresenter(interactor: interactor)
        // 3. View（見た目）を作り、Presenterを渡す
        let view = SplitBillView(presenter: presenter)
        
        // AnyViewで包んで返す（SwiftUIの画面として表示できるようにするため）
        return AnyView(view)
    }
}
