//
//  RoundingUnitPicker.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/05/02.
//

import SwiftUI

struct RoundingUnitPicker: View {
    @Binding var selection: RoundingUnit

    var body: some View {
        Picker("rounding_unit.title", selection: $selection) {
            ForEach(RoundingUnit.allCases, id: \.self) { unit in
                Text(unit.displayName).tag(unit)
            }
        }
    }
}

#Preview {
    RoundingUnitPickerPreview()
}

private struct RoundingUnitPickerPreview: View {
    @State private var selection = RoundingUnit.hundred

    var body: some View {
        Form {
            RoundingUnitPicker(selection: $selection)
        }
    }
}
