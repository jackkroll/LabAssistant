//
//  PresetView.swift
//  LabAssistant
//
//  Created by Jack Kroll on 10/29/25.
//

import SwiftUI
import SwiftData

// Build an agitation substep process: initial 30s, then 10s each minute
let agitation = SubstepProcess(title: "Agitation", duration: 10, gap: 50)

// Build steps using SingleStep, filling all properties
let steps: [SingleStep] = [
    SingleStep(
        title: "Prepare Chemicals",
        index: 0,
        notes: "Mix Ilfotec DD-X 1+4 at 20°C. Prepare stop and fixer.",
        autoAdvance: true,
        associatedChemicals: [],
        totalDuration: nil,
        substep: nil
    ),
    SingleStep(
        title: "Develop",
        index: 1,
        notes: "Total 9:00. Initial 30s agitation, then 10s each minute.",
        autoAdvance: false,
        associatedChemicals: [],
        totalDuration: 9 * 60,
        substep: agitation
    ),
    SingleStep(
        title: "Stop Bath",
        index: 2,
        notes: "Ilfostop 1+19, 30s continuous agitation.",
        autoAdvance: true,
        associatedChemicals: [],
        totalDuration: 30,
        substep: nil
    ),
    SingleStep(
        title: "Fix",
        index: 3,
        notes: "Rapid Fixer 1+4, 5 min. Agitate first 30s, then 10s each minute.",
        autoAdvance: false,
        associatedChemicals: [],
        totalDuration: 5 * 60,
        substep: agitation
    ),
    SingleStep(
        title: "Wash",
        index: 4,
        notes: "Running water 5–10 min (Ilford method acceptable).",
        autoAdvance: true,
        associatedChemicals: [],
        totalDuration: 7 * 60,
        substep: nil
    ),
    SingleStep(
        title: "Final Rinse",
        index: 5,
        notes: "Photo-Flo per instructions. Hang to dry.",
        autoAdvance: true,
        associatedChemicals: [],
        totalDuration: 60,
        substep: nil
    )
]

let ilfordBW = DevProcess(
    nickname: "HP5+ in DD-X",
    steps: steps
)

struct PresetView: View {
    @Environment(\.modelContext) private var modelContext
    var body: some View {
        VStack {
            Button("Add Ilford HP5+ in DD-X") {
                modelContext.insert(ilfordBW)
                try? modelContext.save()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    
}

#Preview {
    PresetView()
}
