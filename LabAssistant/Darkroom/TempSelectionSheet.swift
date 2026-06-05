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
    @State private var requestedAutoTemp: Double = 20
    var body: some View {
        ScrollView {
            let currentPreset = step.currentPreset
            let availablePresets = step.sortedTemperatureDurations.filter { $0.duration != step.totalDuration }
            let autoTimeDuration = step.autoTimeDuration

            if let totalDuration = step.totalDuration {
                HStack {
                    Text("Current")
                        .bold()
                    Spacer()
                }
                HStack {
                    if step.usesAutoTimeTiming {
                        Label("Auto Time", systemImage: "bolt.badge.clock.fill")
                            .fontWeight(.semibold)
                        if let requestedTemperature = step.requestedTemperatureMeasurement {
                            Text("@ \(requestedTemperature.value.formatted(.number))\(requestedTemperature.unit.symbol)")
                        }
                        Spacer(minLength: 0)
                        if let autoTimeDuration {
                            Text(autoTimeDuration.formatToMinSec())
                        } else {
                            Text(totalDuration.formatToMinSec())
                        }
                    } else if let currentPreset {
                        Text("\(currentPreset.duration.formatToMinSec())")
                        if let temperature = currentPreset.temperature {
                            Text("@ \(temperature.formatted(.number))\(currentPreset.units.symbol)")
                        }
                    } else {
                        Text(totalDuration.formatToMinSec())
                    }
                    Spacer(minLength: 0)
                }
                .font(.title3)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.bar)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .bold()
                Divider()
            }

            if let autoTimeDuration {
                HStack {
                    Text("Auto Time")
                    if step.usesAutoTimeTiming {
                        Text("(Selected)")
                            .foregroundStyle(.secondary)
                    }
                }
                .bold()
                .padding(.top, 4)
                
                
                HStack {
                    if step.usesAutoTimeTiming {
                        Stepper("Requested Temperature", value: $requestedAutoTemp, in: 16...36)
                            .onAppear {
                                requestedAutoTemp = step.requestedTemperature ?? 20
                            }
                            .onChange(of: requestedAutoTemp) { _, new in
                                step.requestedTemperature = new
                                _ = step.selectAutoTime()
                            }
                    }
                    else {
                        Label("Auto Time", systemImage: "bolt.badge.clock.fill")
                            .fontWeight(.semibold)
                        if let requestedTemperature = step.requestedTemperatureMeasurement {
                            Text("@ \(requestedTemperature.value.formatted(.number))\(requestedTemperature.unit.symbol)")
                        }
                        Spacer(minLength: 0)
                        Text(autoTimeDuration.formatToMinSec())
                    }
                    
                }
                .font(.title3)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.bar)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .bold()
                .onTapGesture {
                    if !step.usesAutoTimeTiming {
                        _ = step.selectAutoTime()
                    }
                }
            }

            if availablePresets.isEmpty {
                ContentUnavailableView("No More Presets to Change to", systemImage: "thermometer.medium.slash", description: Text("Add more presets to select from"))
            } else {
                Text("Available Presets")
                ForEach(availablePresets) { temp in
                    HStack {
                        Text("\(temp.duration.formatToMinSec())")
                        if let temperature = temp.temperature {
                            Text("@ \(temperature.formatted(.number))\(temp.units.symbol)")
                        }
                        Spacer(minLength: 0)
                    }
                    .font(.title3)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.bar)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .bold()
                    .onTapGesture {
                        if !step.usesAutoTimeTiming && step.currentPreset == nil && step.totalDuration != nil {
                            displayRemovalAlert = true
                        } else {
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
            step.selectPreset(preset)
        }
    }
}

#Preview {
    @Previewable @State var isPresented: Bool = true
    VStack {
        
    }
    .sheet(isPresented: $isPresented) {
        NavigationStack {
            TempSelectionSheet(step: SingleStep(title: "Test Step", index: 0, autoAdvance: false, associatedChemicals: [], totalDuration: 9*60, requestedTemperature: 21, requestedTemperatureUnits: .celsius, tempDuration: [.init(temperature: 20, units: .celsius, duration: 9*60), .init(temperature: 22, duration: 8*60)]))
        }
    }
}

#Preview {
    TempSelectionSheet(step: SingleStep(title: "Test Step", index: 0, autoAdvance: false, associatedChemicals: [], totalDuration: 9*60, requestedTemperature: 21, requestedTemperatureUnits: .celsius, tempDuration: [.init(temperature: 20, units: .celsius, duration: 9*60), .init(temperature: 22, duration: 8*60)]))
}
#Preview {
    TempSelectionSheet(step: SingleStep(title: "Test Step", index: 0, autoAdvance: false, associatedChemicals: []))
}
