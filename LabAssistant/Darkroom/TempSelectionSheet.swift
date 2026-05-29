//
//  TempSelectionSheet.swift
//  LabAssistant
//
//  Created by Jack Kroll on 5/28/26.
//

import SwiftUI

struct TempSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let step : SingleStep
    @State private var displayRemovalAlert: Bool = false
    var body: some View {
        ScrollView{
            if let tempDuration = step.tempDuration, tempDuration.count > 0 {
                if let totalDuration = step.totalDuration {
                    HStack{
                        Text("Current")
                            .bold()
                        Spacer()
                    }
                    HStack {
                        Text("\(totalDuration.formatToMinSec())")
                        if let correspondingPreset = step.tempDuration?.first(where: {$0.duration == totalDuration}), let temperature = correspondingPreset.temperature {
                            Text("@ \(temperature.formatted(.number))\(correspondingPreset.units.symbol)")
                        }
                    }
                    .font(.title3)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .bold()
                    Divider()
                }
                if tempDuration.count(where: {$0.duration != step.totalDuration}) > 0 {
                    Text("Available Presets")
                    ForEach(tempDuration.sorted(by: { $0.duration > $1.duration }).filter({$0.duration != step.totalDuration})) { temp in
                        HStack {
                            Text("\(temp.duration.formatToMinSec())")
                            if let temperature = temp.temperature {
                                Text("@ \(temperature.formatted(.number))\(temp.units.symbol)")
                            }
                        }
                        .font(.title3)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Material.thick)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .bold()
                        .onTapGesture {
                            if !(step.tempDuration?.contains(where: { $0.duration == step.totalDuration }) ?? false) && step.totalDuration != nil{
                                displayRemovalAlert = true
                            }
                            else {
                                selectPreset(preset: temp)
                            }
                        }
                        .alert(
                            "Warning",
                            isPresented: $displayRemovalAlert
                        ) {
                            Button("Create a new preset", role: .confirm) {
                                step.tempDuration?.append(.init(temperature: nil, duration: step.totalDuration ?? 60))
                                selectPreset(preset: temp)
                            }
                            .keyboardShortcut(.defaultAction)
                            Button(role: .destructive) {
                                selectPreset(preset: temp)
                            } label: {
                                Text("Replace")
                            }
                        } message: {
                            Text("There is not a preset with the current timing")
                        }
                    }
                }
                else {
                    ContentUnavailableView("No More Presets to Change to", systemImage: "thermometer.medium.slash", description: Text("Add more presets to select from"))
                }
            }
            else {
                ContentUnavailableView("No Presets Created", systemImage: "thermometer.medium.slash", description: Text("Edit the step to add time/temperature presets"))
            }
        }
        .padding()
        
        .navigationTitle("Presets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(role: .close) {
                dismiss()
            }
        }
    }
    private func selectPreset(preset: TemperatureDuration) {
        withAnimation {
            step.totalDuration = preset.duration
            dismiss()
        }
    }
}

#Preview {
    @Previewable @State var isPresented: Bool = true
    VStack {
        
    }
    .sheet(isPresented: $isPresented) {
        NavigationStack {
            TempSelectionSheet(step: SingleStep(title: "Test Step", index: 0, autoAdvance: false, associatedChemicals: [], totalDuration: 500,tempDuration: [.init(temperature: 20, units: .celsius, duration: 9*60), .init(temperature: nil, duration: 5*60)]))
                .presentationDetents([.medium, .large])
        }
    }
}

#Preview {
    TempSelectionSheet(step: SingleStep(title: "Test Step", index: 0, autoAdvance: false, associatedChemicals: [], totalDuration: 9*60,tempDuration: [.init(temperature: 20, units: .celsius, duration: 9*60)]))
}
#Preview {
    TempSelectionSheet(step: SingleStep(title: "Test Step", index: 0, autoAdvance: false, associatedChemicals: []))
}
