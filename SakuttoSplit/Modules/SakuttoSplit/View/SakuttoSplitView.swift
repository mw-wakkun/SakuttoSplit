//
//  SakuttoSplitView.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// 割り勘計算画面のメインView
struct SakuttoSplitView: View {

    @ObservedObject var presenter: SakuttoSplitPresenter
    let bannerAdUnitID: String

    var body: some View {
        NavigationStack { // iOS 16以降の推奨
            Form {
                // MARK: お会計設定
                Section("お会計設定") {
                    totalAmountField
                    roundingUnitPicker
                }

                // MARK: 参加者グループ
                Section("参加者グループ") {
                    groupsList
                    addGroupButton
                }

                // MARK: 計算結果
                Section("計算結果") {
                    resultsList
                    summarySection
                    shareButton
                }
            }
            .navigationTitle("サクッと割り勘")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { hideKeyboard() }
                }
            }
        }
        // MARK: 広告バナー表示
        AdBannerView(adUnitID: bannerAdUnitID)
            .frame(height: 50)
    }
}

// MARK: - View Components

private extension SakuttoSplitView {

    var totalAmountField: some View {
        HStack {
            TextField("例: 35000", text: totalAmountBinding)
                .keyboardType(.numberPad)
                .font(.title2)
            Text("円")
        }
    }

    var roundingUnitPicker: some View {
        Picker("割り勘の単位", selection: roundingUnitBinding) {
            ForEach(RoundingUnit.allCases, id: \.self) { unit in
                Text(unit.displayName).tag(unit)
            }
        }
    }

    var groupsList: some View {
        ForEach(presenter.viewState.groups) { group in
            VStack(spacing: 12) {
                // 上段：グループ名・人数・削除
                HStack {
                    TextField("グループ名", text: nameBinding(for: group.id))
                        .textFieldStyle(.roundedBorder)

                    stepperSection(for: group)

                    deleteButton(for: group.id)
                }

                // 下段：モード切替・詳細入力
                HStack {
                    Picker("モード", selection: paymentModeBinding(for: group.id)) {
                        Text("割合").tag(PaymentMode.ratio)
                        Text("固定額").tag(PaymentMode.fixed)
                    }
                    .pickerStyle(.segmented)

                    detailInputField(for: group)
                }
            }
            .padding(.vertical, 4)
        }
    }

    func stepperSection(for group: AttendeeGroupDraft) -> some View {
        HStack(spacing: 8) {
            let currentCount = Int(group.countText) ?? 1

            Button(action: {
                if currentCount > InputLimits.groupCountRange.lowerBound {
                    presenter.didChangeGroupCount(id: group.id, countText: "\(currentCount - 1)")
                }
            }) {
                Image(systemName: "minus.circle.fill").font(.title3)
            }
            .buttonStyle(.borderless)
            .disabled(currentCount <= InputLimits.groupCountRange.lowerBound)

            TextField("", text: countBinding(for: group.id))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 35)

            Button(action: {
                if currentCount < InputLimits.groupCountRange.upperBound {
                    presenter.didChangeGroupCount(id: group.id, countText: "\(currentCount + 1)")
                }
            }) {
                Image(systemName: "plus.circle.fill").font(.title3)
            }
            .buttonStyle(.borderless)

            Text("人")
        }
    }

    func detailInputField(for group: AttendeeGroupDraft) -> some View {
        HStack {
            if group.mode == .fixed {
                TextField("金額", text: fixedAmountBinding(for: group.id))
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                Text("円")
            } else {
                TextField("倍率", text: ratioBinding(for: group.id))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Text("倍")
            }
        }
    }

    func deleteButton(for id: UUID) -> some View {
        Button(role: .destructive) {
            presenter.didTapRemoveGroup(id: id)
        } label: {
            Image(systemName: "trash").foregroundColor(.red)
        }
        .buttonStyle(.borderless)
    }

    var addGroupButton: some View {
        Button(action: { presenter.didTapAddGroup() }) {
            Label("グループを追加", systemImage: "plus.circle.fill")
        }
    }

    var resultsList: some View {
        ForEach(presenter.viewState.results) { result in
            HStack {
                Text(result.name)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("1人 \(result.amountPerPerson)円").bold()
                    Text("(合計 \(result.total)円)").font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }

    var summarySection: some View {
        HStack {
            Text(presenter.viewState.difference >= 0 ? "✨ 余剰金" : "⚠️ 不足金")
            Spacer()
            Text("\(abs(presenter.viewState.difference)) 円")
                .bold()
                .foregroundColor(presenter.viewState.difference >= 0 ? .green : .red)
        }
    }

    var shareButton: some View {
        ShareLink(item: presenter.shareText()) {
            Label("結果をLINE等でシェア", systemImage: "message.fill")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .listRowBackground(Color.green) // ボタンの背景を緑にする
    }
}

// MARK: - Intent Bindings

private extension SakuttoSplitView {

    var totalAmountBinding: Binding<String> {
        Binding(
            get: { presenter.viewState.totalAmountText },
            set: { presenter.didChangeTotalAmount($0) }
        )
    }

    var roundingUnitBinding: Binding<RoundingUnit> {
        Binding(
            get: { presenter.viewState.roundingUnit },
            set: { presenter.didChangeRoundingUnit($0) }
        )
    }

    func nameBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { presenter.viewState.groups.first(where: { $0.id == id })?.name ?? "" },
            set: { presenter.didChangeGroupName(id: id, name: $0) }
        )
    }

    func countBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { presenter.viewState.groups.first(where: { $0.id == id })?.countText ?? "" },
            set: { presenter.didChangeGroupCount(id: id, countText: $0) }
        )
    }

    func paymentModeBinding(for id: UUID) -> Binding<PaymentMode> {
        Binding(
            get: { presenter.viewState.groups.first(where: { $0.id == id })?.mode ?? .ratio },
            set: { presenter.didChangePaymentMode(id: id, mode: $0) }
        )
    }

    func fixedAmountBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { presenter.viewState.groups.first(where: { $0.id == id })?.fixedAmountText ?? "" },
            set: { presenter.didChangeFixedAmount(id: id, text: $0) }
        )
    }

    func ratioBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { presenter.viewState.groups.first(where: { $0.id == id })?.ratioText ?? "" },
            set: { presenter.didChangeRatio(id: id, text: $0) }
        )
    }
}
