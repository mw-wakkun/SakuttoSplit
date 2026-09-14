//
//  BillSessionContract.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import Foundation

/// 前回会計とメンバーセットの永続化。計算も広告も知らない
protocol BillSessionStoring {
    var lastBill: BillSnapshot? { get }
    func saveLastBill(_ snapshot: BillSnapshot)
    func clearLastBill()

    var memberSets: [MemberSet] { get }
    /// 空き枠がある、または同一 id の更新なら保存する。拒否したら false
    @discardableResult
    func saveMemberSet(_ memberSet: MemberSet) -> Bool
    func deleteMemberSet(id: UUID)

    /// 1...3。未設定は 1
    var slotCount: Int { get }
    /// 上限未満なら +1 して true。既に 3 なら false
    @discardableResult
    func unlockExtraSlot() -> Bool
}
