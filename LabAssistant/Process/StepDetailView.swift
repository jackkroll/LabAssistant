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
    @State private var editingTemperatureDuration: TemperatureDuration? = nil
    @State private var showAutoTimeRequirements: Bool = false
    
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
                        if ((step.tempDuration?.count(where: {$0.temperature != nil}) ?? 0) > 0) {
                            if step.totalDuration ?? .infinity <= 5 * 60 {
                                Text("Low Time Warning")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.18))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                                
                        }
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
            Section("Auto Time") {
                if let temp = step.autoTimePreset {
                    let developerBehavior = step.developerBehavior()
                    let excludedAutoTime = step.autoTimePreset
                    let hasEnoughPresets = step.temperatureEstimatePresetCountExcluding(excludedAutoTime) >= 2
                    let hasPresetRange = step.hasTemperatureEstimatePresetRangeExcluding(excludedAutoTime)
                    let temperatureInRange = temp.measurement.map { SingleStep.isTemperatureInEstimateRange($0) } ?? false
                    let isSelected: Bool = step.totalDuration.map { $0 == temp.duration } ?? false

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Auto Time", systemImage: "bolt.badge.clock.fill")
                                .fontWeight(.semibold)
                            Spacer(minLength: 0)
                            if let temperature = temp.temperature {
                                Text("@")
                                Text("\(temperature.formatted())\(temp.units.symbol)")
                            } else {
                                Text("No temperature assigned")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.title3)
                        
                        HStack {
                            Button(isSelected ? "Selected" : "Select") {
                                if !(step.tempDuration?.contains(where: { $0.duration == step.totalDuration }) ?? false) && step.totalDuration != nil {
                                    displayRemovalAlert = true
                                } else {
                                    selectPreset(preset: temp)
                                }
                            }
                            .disabled(!step.autoTimeAvailability)
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

                            Button {
                                editingTemperatureDuration = temp
                            } label: {
                                Text("Edit")
                                    .frame(maxWidth: .infinity)
                                    .padding(7)
                                    .background(.orange)
                                    .clipShape(.capsule)
                            }
                            .buttonStyle(.plain)
                            .buttonSizing(.flexible)
                        }
                        
                        DisclosureGroup {
                            Text("This value is calculated based on your current presets and then compared to expected temperature response values.")
                        } label: {
                            HStack {
                                Text("Temperature Response")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Label(developerBehavior.title, systemImage: developerBehavior.systemImage)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(developerBehavior.tint.opacity(0.18))
                                    .foregroundStyle(developerBehavior.tint)
                                    .clipShape(Capsule())
                            }
                            .font(.callout)
                        }
                        DisclosureGroup(isExpanded: $showAutoTimeRequirements) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("At least 2 presets with temperature/time pairs")
                                    Spacer()
                                    Image(systemName: hasEnoughPresets ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(hasEnoughPresets ? .green : .secondary)
                                }
                                HStack {
                                    Text("Preset temperatures span at least 2ºC")
                                    Spacer()
                                    Image(systemName: hasPresetRange ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(hasPresetRange ? .green : .secondary)
                                }
                                HStack {
                                    Text("Temperature stays between 16ºC and 36ºC")
                                    Spacer()
                                    Image(systemName: temperatureInRange ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(temperatureInRange ? .green : .secondary)
                                }
                            }
                            .font(.callout)
                        } label: {
                            HStack {
                                Text("Requirements")
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 5)
                                Spacer()
                                Image(systemName: step.autoTimeAvailability ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(step.autoTimeAvailability ? .green : .secondary)
                            }
                        }
                        DisclosureGroup {
                            Text("Auto Time is calculated based on your presets, before important work always double check with the manufacturer.")
                        } label: {
                            Text("Additional Notes")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 5)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Auto Time Not Available",
                        systemImage: "bolt.badge.clock.fill",
                        description: Text("Add an Auto Time preset to edit its temperature and see its accuracy requirements.")
                    )
                }
            }
            Section {
                ForEach(step.sortedTemperatureDurations.filter { !$0.isAutoTime }) { temp in
                    let isSelected: Bool = step.totalDuration.map { $0 == temp.duration } ?? false
                    VStack{
                        HStack {
                            Text(temp.duration.formatToMinSec())
                            if let temperature = temp.temperature{
                                Text("@")
                                Text("\(temperature.formatted())\(temp.units.symbol)")
                            }
                            Spacer(minLength: 0)
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
                                _ = step.recalculateAutoTimePreset()
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
            } footer: {
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
        .onAppear {
            _ = step.recalculateAutoTimePreset()
        }
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
        .sheet(item: $editingTemperatureDuration) { temp in
            NavigationStack {
                TempDurationEditorView(step: step, inputTempDuration: temp)
                    .navigationTitle("Edit Auto Time")
                    .navigationBarTitleDisplayMode(.inline)
                    .presentationDetents([.medium, .large])
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

    private var isEditingAutoTimePreset: Bool {
        inputTempDuration?.isAutoTime == true
    }
    
    init(step: SingleStep, inputTempDuration: TemperatureDuration? = nil) {
        self.step = step
        self.inputTempDuration = inputTempDuration
        
        let duration = inputTempDuration?.duration.rounded(.down)
        if let inputTempDuration = inputTempDuration {
            _temperature = State(initialValue: inputTempDuration.temperature)
        } else {
            _temperature = State(initialValue: 20)
        }
        _units = State(initialValue: inputTempDuration?.units ?? .celsius)
        _selectedMinutes = State(initialValue: duration.map { Int($0 / 60) } ?? 9)
        _selectedSeconds = State(initialValue: duration.map { Int($0.truncatingRemainder(dividingBy: 60)) } ?? 30)
        _temperatureDenoted = State(initialValue: inputTempDuration?.isAutoTime == true ? true : (inputTempDuration.map { $0.temperature != nil } ?? true))
    }
    
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
                    .disabled(isEditingAutoTimePreset ? false : !temperatureDenoted)

                    if !isEditingAutoTimePreset {
                        Toggle("Preset includes temperature", isOn: $temperatureDenoted)
                            .onChange(of: temperatureDenoted) { _, newValue in
                                if !newValue {
                                    temperature = nil
                                } else {
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
                }

                if !isEditingAutoTimePreset {
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
            }
            .onAppear {
                if !isEditingAutoTimePreset {
                    refreshLinkedAutoTimePreset()
                }
            }
            .onChange(of: temperature) { _, new in
                if !isEditingAutoTimePreset {
                    refreshLinkedAutoTimePreset()
                }
            }
            .onChange(of: units) { old, new in
                if let oldTemp = temperature {
                    temperature = Measurement(value: oldTemp, unit: old).converted(to: new).value
                }
                if !isEditingAutoTimePreset {
                    refreshLinkedAutoTimePreset()
                }
            }
            .onChange(of: selectedMinutes) { _, _ in
                if !isEditingAutoTimePreset {
                    refreshLinkedAutoTimePreset()
                }
            }
            .onChange(of: selectedSeconds) { _, _ in
                if !isEditingAutoTimePreset {
                    refreshLinkedAutoTimePreset()
                }
            }
            .onChange(of: validateEditsMade()) { _, new in
                editsMade = new
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
                        let newTempDuration = TemperatureDuration(
                            temperature: temperature,
                            units: units,
                            duration: TimeInterval((selectedMinutes * 60) + selectedSeconds)
                        )
                        step.tempDuration?.append(newTempDuration)
                    } else if let tempDuration = inputTempDuration {
                        tempDuration.temperature = temperature
                        tempDuration.units = units
                        if isEditingAutoTimePreset {
                            if let estimated = step.timeEstimate(at: Measurement(value: temperature ?? 20, unit: units), excluding: tempDuration)?.duration {
                                tempDuration.duration = estimated
                            }
                        } else {
                            tempDuration.duration = TimeInterval((selectedMinutes * 60) + selectedSeconds)
                        }
                    }
                    step.recalculateAutoTimePreset(excluding: inputTempDuration)
                    dismiss()
                }
                .disabled(!editsMade && inputTempDuration != nil)
            }
        }
        .navigationBarBackButtonHidden()
        .navigationTitle(isEditingAutoTimePreset ? "Edit Auto Time" : (inputTempDuration == nil ? "Add Preset" : "Edit Preset"))
    }

    private func refreshLinkedAutoTimePreset() {
        guard !isEditingAutoTimePreset else { return }
        _ = step.recalculateAutoTimePreset(excluding: inputTempDuration)
    }

    func validateEditsMade() -> Bool {
        guard let inputTempDuration else { return true }
        if isEditingAutoTimePreset {
            return inputTempDuration.temperature != temperature
            || inputTempDuration.units != units
        }
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
            TemperatureDuration(temperature: 21, units: .celsius, duration: 60, isAutoTime: true)
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
            TemperatureDuration(temperature: 23, units: .celsius, duration: 10.5 * 60, isAutoTime: true)
        ]
    )
    TempDurationEditorView(step: step)
}
