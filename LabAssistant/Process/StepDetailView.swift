// StepDetailView.swift
// A dedicated editor for a SingleStep
import SwiftUI
import SwiftData

struct StepDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var step: SingleStep
    
    @State private var durationMinutes: String = ""
    @Query private var allChemicals: [Chemical]
    @State private var selectedChemicalID: PersistentIdentifier?
    @State private var isEditingSubstep: Bool = false
    
    @State private var displayRemovalAlert: Bool = false
    
    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $step.title)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                TextField("Notes", text: $step.notes, axis: .vertical)
                    .multilineTextAlignment(.leading)
            }
            
            Section("Timing") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TextField("Duration (minutes) (optional)", text: $durationMinutes)
                            .keyboardType(.decimalPad)
                            .contentTransition(.numericText())
                            .animation(.easeInOut, value: durationMinutes)
                        Spacer()
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                    .onAppear {
                        withAnimation {
                            durationMinutes = ((step.totalDuration ?? 0)/60).description
                        }
                    }
                    .onChange(of: durationMinutes) { oldValue, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                        if let mins = Double(trimmed), mins >= 0 {
                            step.totalDuration = Double(mins * 60)
                        } else if trimmed.isEmpty {
                            step.totalDuration = nil
                        }
                    }
                }
                
                Toggle("Auto-advance", isOn: $step.autoAdvance)
            }
            Section {
                ForEach((step.tempDuration ?? []).sorted(by: { $0.duration > $1.duration })) { temp in
                    let isSelected: Bool = step.totalDuration.map { $0 == temp.duration } ?? false
                    VStack{
                        HStack {
                            Text(temp.duration.formatToMinSec())
                            if let temperature = temp.temperature{
                                Text("@")
                                Text("\(temperature.formatted())\(temp.units.symbol)")
                            }
                        }
                        .font(.title3)
                        .padding(.horizontal)
                        HStack {
                            Button(isSelected ? "Selected" : "Select") {
                                // If the selection would delete the current timing that isn't already a preset
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
                            
                            .disabled(isSelected)
                            .buttonStyle(.borderedProminent)
                            .buttonSizing(.flexible)
                            
                            
                            NavigationLink {
                                TempDurationEditorView(step: step, inputTempDuration: temp)
                            } label: {
                                Text("Edit")
                                    .frame(maxWidth: .infinity)
                                    .padding(7)
                                    .background(.orange)
                                    .clipShape(.capsule)
                                
                            }
                            .navigationLinkIndicatorVisibility(.hidden)
                            
                            Button("Remove", role: .destructive) {
                                step.tempDuration?.removeAll(where: { $0.duration == temp.duration && $0.temperature == temp.temperature && $0.units == temp.units })
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonSizing(.flexible)
                            
                        }
                        
                        
                    }
                    
                }
                NavigationLink {
                    TempDurationEditorView(step: step)
                    
                } label: {
                    Label("Add Options", systemImage: "plus")
                        .foregroundStyle(.blue)
                }
                .navigationLinkIndicatorVisibility(.hidden)
                
            } header: {
                Text("Temperature Time Presets")
            } footer : {
                Text("Add presets to easily select the correct temperature when you're ready to develop")
            }
            
            Section("Substep") {
                if let sub = step.substep {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(sub.title)
                                .font(.body)
                            Text("Duration: \(Int(sub.duration)) sec, Gap: \(Int(sub.gap)) sec")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Edit") { isEditingSubstep = true }
                    }
                    Button(role: .destructive) {
                        step.substep = nil
                    } label: {
                        Label("Remove Substep", systemImage: "trash")
                    }
                } else {
                    Button {
                        step.substep = SubstepProcess(title: "Untitled", duration: 15, gap: 45)
                        isEditingSubstep = true
                    } label: {
                        Label("Add Substep", systemImage: "plus")
                    }
                }
            }
            if step.associatedChemicals != nil {
                Section("Associated Chemicals") {
                    if allChemicals.isEmpty {
                        ContentUnavailableView("No chemicals in library", systemImage: "testtube.2", description: Text("Add chemicals to your library to use them here."))
                    } else {
                        Picker("Add from library", selection: Binding<PersistentIdentifier?>(
                            get: { selectedChemicalID },
                            set: { newValue in
                                selectedChemicalID = newValue
                                guard let id = newValue, let chem = allChemicals.first(where: { $0.id == id }) else { return }
                                if !step.associatedChemicals!.contains(where: { $0.id == chem.id }) {
                                    step.associatedChemicals!.append(chem)
                                }
                                // reset selection so the same item can be picked again later if removed
                                selectedChemicalID = nil
                            }
                        )) {
                            Text("None").tag(PersistentIdentifier?.none)
                            ForEach(allChemicals) { chem in
                                Text(chem.nickname).tag(PersistentIdentifier?.some(chem.id))
                            }
                        }
                    }
                    if !allChemicals.isEmpty {
                        if step.associatedChemicals!.isEmpty == false {
                            ForEach(step.associatedChemicals!, id: \.self) { chem in
                                Text(chem.nickname)
                            }
                            .onDelete { indices in
                                step.associatedChemicals!.remove(atOffsets: indices)
                            }
                        } else {
                            ContentUnavailableView("No chemicals selected", systemImage: "testtube.2", description: Text("Pick from your chemicals library above."))
                        }
                    }
                }
            }
            
            
        }
        .navigationTitle("Edit Step")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditingSubstep) {
            NavigationStack {
                if let _ = step.substep {
                    SubstepEditor(substep: Binding(get: { step.substep! }, set: { step.substep = $0 }))
                        .navigationTitle("Edit Substep")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(role: .confirm) { isEditingSubstep = false }
                            }
                        }
                } else {
                    Text("No substep to edit")
                }
            }
        }
    }
    
    private func selectPreset(preset: TemperatureDuration) {
        withAnimation {
            step.totalDuration = preset.duration
            durationMinutes = (preset.duration / 60).description
        }
    }
}
private struct TempDurationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let step: SingleStep
    var inputTempDuration: TemperatureDuration? = nil
    @State private var temperature: Double? = 20
    @State private var units: UnitTemperature = .celsius
    @State private var selectedMinutes: Int = 9
    @State private var selectedSeconds: Int = 30
    @State private var temperatureDenoted: Bool = true
    
    @State private var editsMade: Bool = false
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    var body: some View {
        VStack {
            Form {
                Section("Temperature") {
                    
                    HStack {
                        TextField("Temperature Preset", value: $temperature, formatter: formatter)
                            .keyboardType(.decimalPad)
                            .foregroundStyle(temperatureDenoted ? .primary : .secondary)
                        Picker("Units", selection: $units) {
                            ForEach([UnitTemperature.celsius, UnitTemperature.fahrenheit], id: \.self) { temperature in
                                Text(temperature.symbol)
                            }
                        }
                        .pickerStyle(.palette)
                        
                    }
                    .disabled(!temperatureDenoted)
                    Toggle("Modify Step Temperature", isOn: $temperatureDenoted)
                        .onChange(of: temperatureDenoted) { _,newValue in
                            if !newValue {
                                temperature = nil
                            }
                            else {
                                switch units {
                                case .celsius:
                                    temperature = 20
                                case .fahrenheit:
                                    temperature = 68
                                default:
                                    temperature = 20
                                }
                            }
                        }
                }
                Section("Duration") {
                    VStack {
                        HStack {
                            Picker("Minutes", selection: $selectedMinutes) {
                                ForEach(0..<60) { i in Text("\(i) min").tag(i) }
                            }
                            Text(":")
                            Picker("Seconds", selection: $selectedSeconds) {
                                ForEach(0..<60) { i in
                                    HStack {
                                        Text(i, format: .number.precision(.integerLength(2...)))
                                        Text("sec")
                                    }
                                    .tag(i)
                                }
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                }
            }
            .onChange(of: validateEditsMade()) { _, new in
                editsMade = new
            }
            .onAppear {
                if let tempDuration = inputTempDuration {
                    temperature = tempDuration.temperature
                    units = tempDuration.units
                    let minutes = Int(tempDuration.duration.rounded(.down) / 60)
                    let seconds = Int(tempDuration.duration.rounded(.down).truncatingRemainder(dividingBy: 60))
                    selectedMinutes = minutes
                    selectedSeconds = seconds
                    temperatureDenoted = tempDuration.temperature != nil
                }
                
            }
            
        }
        .toolbar {
            let shouldAdd = inputTempDuration == nil
            ToolbarItem(placement: .topBarLeading) {
                Button(role: shouldAdd ? .destructive : .cancel) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .confirm) {
                    if shouldAdd {
                        if step.tempDuration == nil {
                            step.tempDuration = []
                        }
                        step.tempDuration?.append(
                            .init(
                                temperature: temperature,
                                units: units,
                                duration: TimeInterval(((selectedMinutes * 60) + selectedSeconds)))
                        )
                    }
                    else if let tempDuration = inputTempDuration{
                        tempDuration.temperature = temperature
                        tempDuration.units = units
                        tempDuration.duration = TimeInterval(((selectedMinutes * 60) + selectedSeconds))
                    }
                    dismiss()
                }
                .disabled(!editsMade && inputTempDuration != nil)
                
            }
            
        }
        .navigationBarBackButtonHidden()
    }
    func validateEditsMade() -> Bool {
        guard let inputTempDuration else { return true }
        return inputTempDuration.temperature != temperature
        || inputTempDuration.units != units
        || Int(inputTempDuration.duration.rounded(.down)) != ((selectedMinutes * 60) + selectedSeconds)
    }
}

private struct SubstepEditor: View {
    @Binding var substep: SubstepProcess
    @State private var title: String = ""
    @State private var durationText: String = ""
    @State private var gapText: String = ""
    
    init(substep: Binding<SubstepProcess>) {
        self._substep = substep
        self._title = State(initialValue: substep.wrappedValue.title)
        self._durationText = State(initialValue: String(substep.wrappedValue.duration))
        self._gapText = State(initialValue: String(substep.wrappedValue.gap))
    }
    
    var body: some View {
        Form {
            Section("Basics") {
                TextField("Title", text: $title)
                    .onChange(of: title) { _, newValue in
                        substep.title = newValue
                    }
            }
            Section("Timing") {
                HStack {
                    Text("Duration:")
                    TextField("(seconds)", text: $durationText)
                        .keyboardType(.numberPad)
                        .onChange(of: durationText) { _, newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                            if let val = Double(trimmed), val >= 0 { substep.duration = val }
                        }
                    Spacer()
                    Text("sec").foregroundStyle(.secondary)
                }
                HStack {
                    Text("Gap:")
                    TextField("Gap (seconds)", text: $gapText)
                        .keyboardType(.numberPad)
                        .onChange(of: gapText) { _, newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                            if let val = Double(trimmed), val >= 0 { substep.gap = val }
                        }
                    Spacer()
                    Text("sec").foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var step = SingleStep(
        title: "Test Step",
        index: 0,
        notes: "Simple Notes",
        autoAdvance: true,
        associatedChemicals: [Chemical(nickname: "NaCl", max: 100, current: 50)],
        totalDuration: 600,
        substep: SubstepProcess(title:"Untitled Process", duration:15, gap: 45),
        tempDuration: [
            TemperatureDuration(temperature: 68, units: .fahrenheit, duration: 9.5 * 60),
            TemperatureDuration(temperature: 23, units: .celsius, duration: 10.5 * 60),
            TemperatureDuration(temperature: nil, duration: 60)
        ]
    )
    NavigationStack {
        StepDetailView(step: $step)
    }
}

#Preview {
    @Previewable @State var step = SingleStep(
        title: "Test Step",
        index: 0,
        notes: "Simple Notes",
        autoAdvance: true,
        associatedChemicals: [Chemical(nickname: "NaCl", max: 100, current: 50)],
        totalDuration: 600,
        substep: SubstepProcess(title:"Untitled Process", duration:15, gap: 45),
        tempDuration: [
            TemperatureDuration(temperature: 68, units: .fahrenheit, duration: 9.5 * 60),
            TemperatureDuration(temperature: 23, units: .celsius, duration: 10.5 * 60)
        ]
    )
    TempDurationEditorView(step: step)
}

