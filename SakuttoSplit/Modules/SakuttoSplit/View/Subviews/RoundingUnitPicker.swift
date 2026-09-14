//
//  RoundingUnitPicker.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

/// 端数処理単位の選択。常時 5 段にせずディスクロージャにする
struct RoundingUnitPicker: View {
    @Binding var selection: RoundingUnit

    var body: some View {
        Picker("rounding_unit.title", selection: $selection) {
            ForEach(RoundingUnit.allCases, id: \.self) { unit in
                (Text(verbatim: "\(unit.rawValue)") + Text("unit.yen")).tag(unit)
            }
        }
        .pickerStyle(.navigationLink)
    }
}

#Preview {
    RoundingUnitPickerPreview()
}

private struct RoundingUnitPickerPreview: View {
    @State private var selection = RoundingUnit.hundred

    var body: some View {
        NavigationStack {
            Form {
                RoundingUnitPicker(selection: $selection)
            }
        }
    }
}
