//
//  ContentView.swift
//  LetsSplitTheBill
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// 割り勘計算画面のメインView
struct SplitBillView: View {
    
    @ObservedObject var presenter: SplitBillPresenter
    
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
    }
}

// MARK: - View Components

private extension SplitBillView {
    
    var totalAmountField: some View {
        HStack {
            TextField("例: 35000", text: $presenter.totalAmountText)
                .keyboardType(.numberPad)
                .font(.title2)
                .onChange(of: presenter.totalAmountText) {
                    if presenter.totalAmountText.count > 8 {
                        presenter.totalAmountText = String(presenter.totalAmountText.prefix(8))
                    }
                }
            Text("円")
        }
    }
    
    var roundingUnitPicker: some View {
        Picker("割り勘の単位", selection: $presenter.selectedRoundingUnit) {
            ForEach([1, 10, 100, 500, 1000], id: \.self) { unit in
                Text("\(unit)円").tag(unit)
            }
        }
    }
    
    var groupsList: some View {
        ForEach($presenter.groups) { $group in
            VStack(spacing: 12) {
                // 上段：グループ名・人数・削除
                HStack {
                    TextField("グループ名", text: $group.name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: group.name) { presenter.calculate() }
                    
                    stepperSection(for: $group)
                    
                    deleteButton(for: group.id)
                }
                
                // 下段：モード切替・詳細入力
                HStack {
                    Picker("モード", selection: $group.isFixed) {
                        Text("割合").tag(false)
                        Text("固定額").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: group.isFixed) { presenter.calculate() }
                    
                    detailInputField(for: $group)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    func stepperSection(for group: Binding<AttendeeGroup>) -> some View {
        HStack(spacing: 8) {
            let currentCount = Int(group.wrappedValue.countText) ?? 1
            
            Button(action: {
                if currentCount > 1 { group.wrappedValue.countText = "\(currentCount - 1)" }
                presenter.calculate()
            }) {
                Image(systemName: "minus.circle.fill").font(.title3)
            }
            .buttonStyle(.borderless)
            .disabled(currentCount <= 1)

            TextField("", text: group.countText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 35)
                .onChange(of: group.wrappedValue.countText) {
                    presenter.calculate()
                }
            
            Button(action: {
                if currentCount < 999 { group.wrappedValue.countText = "\(currentCount + 1)" }
                presenter.calculate()
            }) {
                Image(systemName: "plus.circle.fill").font(.title3)
            }
            .buttonStyle(.borderless)
            
            Text("人")
        }
    }
    
    func detailInputField(for group: Binding<AttendeeGroup>) -> some View {
        HStack {
            if group.wrappedValue.isFixed {
                TextField("金額", text: group.fixedAmountText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: group.wrappedValue.fixedAmountText) { presenter.calculate() }
                Text("円")
            } else {
                TextField("倍率", text: group.ratioText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: group.wrappedValue.ratioText) { presenter.calculate() }
                Text("倍")
            }
        }
    }
    
    func deleteButton(for id: UUID) -> some View {
        Button(role: .destructive) {
            presenter.removeGroup(id: id)
        } label: {
            Image(systemName: "trash").foregroundColor(.red)
        }
        .buttonStyle(.borderless)
    }
    
    var addGroupButton: some View {
        Button(action: { presenter.addGroup() }) {
            Label("グループを追加", systemImage: "plus.circle.fill")
        }
    }
    
    var resultsList: some View {
        ForEach(presenter.calculationResults, id: \.name) { result in
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
            Text(presenter.difference >= 0 ? "✨ 余剰金" : "⚠️ 不足金")
            Spacer()
            Text("\(abs(presenter.difference)) 円")
                .bold()
                .foregroundColor(presenter.difference >= 0 ? .green : .red)
        }
    }
}
