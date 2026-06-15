// StepDetailView.swift
// A dedicated editor for a SingleStep
import SwiftUI
import SwiftData

struct StepDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var step: SingleStep
    @Query private var allChemicals: [Chemical]
    @State private var selectedChemicalID: PersistentIdentifier?
    @State private var isEditingSubstep: Bool = false
    @State private var editingTemperatureDuration: TemperatureDuration? = nil
    @State private var isEditingRequestedTemperature: Bool = false
    @State private var showAutoTimeRequirements: Bool = false
    @State private var displayRemovalAlert: Bool = false
    @State private var selectedMinutes: Int = 0
    @State private var selectedSeconds: Int = 0
    @State private var hasTiming: Bool = true
    
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
                    if hasTiming {
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
                        .onChange(of: selectedMinutes * 60 + selectedSeconds) {
                            if !step.usesAutoTimeTiming {
                                let duration = TimeInterval(selectedMinutes*60 + selectedSeconds)
                                step.totalDuration = duration
                            }
                        }
                        .overlay {
                            if step.usesAutoTimeTiming {
                                Color.secondary.opacity(0.1)
                                    .clipShape(ConcentricRectangle(corners: .concentric, isUniform: true))
                                Image(systemName: "bolt.badge.clock.fill")
                            }
                        }
                        .pickerStyle(.wheel)
                        .disabled(step.usesAutoTimeTiming)
                        HStack {
                            if let duration = step.totalDuration, duration < 5*60 {
                                Text("Low Development Time")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.orange.opacity(0.18))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                                    
                            }
                            if let temp = step.requestedTemperatureMeasurement, temp.converted(to: .celsius).value > 25 {
                                Text("High Temperature")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.orange.opacity(0.18))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                }
                Toggle("Has Timing", isOn: $hasTiming)
                    .onChange(of: hasTiming) { _, new in
                        if !new {
                            step.totalDuration = nil
                            step.autoAdvance = false
                        }
                        else {
                            step.totalDuration = 9*60 + 30
                        }
                        
                    }
                Toggle("Auto-advance", isOn: $step.autoAdvance)
            }
            .onAppear {
                if let totalDuration = step.totalDuration {
                    selectedMinutes = Int(totalDuration/60)
                    selectedSeconds = Int(totalDuration.truncatingRemainder(dividingBy: 60))
                } else {
                    hasTiming = false
                }
            }
            .onChange(of: step.totalDuration) { _, new in
                if let new = new {
                    withAnimation {
                        selectedMinutes = Int(new/60)
                        selectedSeconds = Int(new.truncatingRemainder(dividingBy: 60))
                    }
                }
            }
            Section("Auto Time") {
                if let requestedTemperature = step.requestedTemperatureMeasurement {
                    let developerBehavior = step.developerBehavior()
                    let hasBasicPreset = step.temperatureEstimatePresetCount >= 1
                    let hasEnhancedPresets = step.temperatureEstimatePresetCount >= 2
                    let hasEnhancedPresetRange = step.hasTemperatureEstimatePresetRange
                    let temperatureInRange = SingleStep.isTemperatureInEstimateRange(requestedTemperature)
                    let estimatedDuration = step.autoTimeDuration
                    let calculationMode = step.autoTimeCalculationMode
                    let isAutoTimeSelected = step.usesAutoTimeTiming

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Auto Time", systemImage: "bolt.badge.clock.fill")
                                .fontWeight(.semibold)
                            if let calculationMode {
                                Text(calculationMode.title)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(calculationMode.tint.opacity(0.18))
                                    .foregroundStyle(calculationMode.tint)
                                    .clipShape(Capsule())
                            }
                            Spacer()
                            Text("@")
                            Text("\(requestedTemperature.value.formatted())\(requestedTemperature.unit.symbol)")
                        }
                        .font(.title3)

                        HStack {
                            if let estimatedDuration {
                                Text("Estimated")
                                if isAutoTimeSelected {
                                    Text("(Applied)")
                                        .foregroundStyle(.secondary)
                                        .bold()
                                }
                                Spacer()
                                Text(estimatedDuration.formatToMinSec())
                            } else {
                                Text("Auto Time unavailable")
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            
                        }

                        HStack {
                            Button(isAutoTimeSelected ? "Turn off" : "Use Auto Time") {
                                if isAutoTimeSelected {
                                    step.turnOffAutoTime()
                                    if let totalDuration = step.totalDuration {
                                        withAnimation {
                                            selectedMinutes = Int(totalDuration / 60)
                                            selectedSeconds = Int(totalDuration.truncatingRemainder(dividingBy: 60))
                                        }
                                    }
                                } else {
                                    _ = step.selectAutoTime()
                                    if let totalDuration = step.totalDuration {
                                        withAnimation {
                                            selectedMinutes = Int(totalDuration / 60)
                                            selectedSeconds = Int(totalDuration.truncatingRemainder(dividingBy: 60))
                                        }
                                    }
                                }
                            }
                            .disabled(estimatedDuration == nil && !isAutoTimeSelected)
                            .buttonStyle(.borderedProminent)
                            .buttonSizing(.flexible)
                            .tint(isAutoTimeSelected ? .gray : .blue)

                            Button {
                                isEditingRequestedTemperature = true
                            } label: {
                                Text("Edit Request")
                                    .frame(maxWidth: .infinity)
                                    .padding(7)
                                    .background(.orange)
                                    .clipShape(.capsule)
                            }
                            .buttonStyle(.plain)
                            .buttonSizing(.flexible)
                        }

                        DisclosureGroup {
                            switch calculationMode {
                            case .basic:
                                Text("Basic Auto Time uses a single preset and the standard temperature response value of 0.08.")
                            case .enhanced:
                                Text("Enhanced Auto Time calculates the temperature response from your presets and the requested temperature.")
                            case .none:
                                Text("Add a valid temperature/time preset to calculate Auto Time.")
                            }
                        } label: {
                            HStack {
                                Text("Temperature Response")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if calculationMode == .enhanced {
                                    Label(developerBehavior.title, systemImage: developerBehavior.systemImage)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(developerBehavior.tint.opacity(0.18))
                                        .foregroundStyle(developerBehavior.tint)
                                        .clipShape(Capsule())
                                } else if let calculationMode {
                                    Text("Using B&W Standard")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(calculationMode.tint.opacity(0.18))
                                        .foregroundStyle(calculationMode.tint)
                                        .clipShape(Capsule())
                                }

                            }
                            .font(.callout)
                        }
                        DisclosureGroup(isExpanded: $showAutoTimeRequirements) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("At least 1 preset with a temperature/time pair")
                                    Spacer()
                                    Image(systemName: hasBasicPreset ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(hasBasicPreset ? .green : .secondary)
                                }
                                HStack {
                                    Text("Enhanced: 2 presets spanning at least 2ºC")
                                    Spacer()
                                    Image(systemName: hasEnhancedPresets && hasEnhancedPresetRange ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(hasEnhancedPresets && hasEnhancedPresetRange ? .green : .secondary)
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
                            Text("Auto Time is calculated from the requested temperature and your presets. Before important work always double check with the manufacturer.")
                        } label: {
                            Text("Additional Notes")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 5)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Auto Time Not Configured",
                        systemImage: "bolt.badge.clock.fill"
                    )
                    Button {
                        isEditingRequestedTemperature = true
                    } label: {
                        Text("Add Auto Time Request")
                    }
                }
            }
            Section {
                ForEach(step.sortedTemperatureDurations) { temp in
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
                                if step.currentPreset == nil && step.totalDuration != nil{
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
                                _ = step.refreshAutoTimeDurationIfNeeded()
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
            _ = step.refreshAutoTimeDurationIfNeeded()
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
                    .navigationTitle("Edit Preset")
                    .navigationBarTitleDisplayMode(.inline)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $isEditingRequestedTemperature) {
            NavigationStack {
                AutoTimeRequestEditorView(step: step)
                    .navigationTitle("Edit Auto Time Request")
                    .navigationBarTitleDisplayMode(.inline)
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    private func selectPreset(preset: TemperatureDuration) {
        withAnimation {
            step.selectPreset(preset)
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
        _temperatureDenoted = State(initialValue: inputTempDuration.map { $0.temperature != nil } ?? true)
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
                    .disabled(!temperatureDenoted)

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
            .onAppear {
                refreshLinkedAutoTimeDuration()
            }
            .onChange(of: temperature) { _, _ in
                refreshLinkedAutoTimeDuration()
            }
            .onChange(of: units) { old, new in
                if let oldTemp = temperature {
                    temperature = Measurement(value: oldTemp, unit: old).converted(to: new).value
                }
                refreshLinkedAutoTimeDuration()
            }
            .onChange(of: selectedMinutes) { _, _ in
                refreshLinkedAutoTimeDuration()
            }
            .onChange(of: selectedSeconds) { _, _ in
                refreshLinkedAutoTimeDuration()
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
                        tempDuration.duration = TimeInterval((selectedMinutes * 60) + selectedSeconds)
                    }
                    _ = step.refreshAutoTimeDurationIfNeeded()
                    dismiss()
                }
                .disabled(!editsMade && inputTempDuration != nil)
            }
        }
        .navigationBarBackButtonHidden()
        .navigationTitle(inputTempDuration == nil ? "Add Preset" : "Edit Preset")
    }

    private func refreshLinkedAutoTimeDuration() {
        _ = step.refreshAutoTimeDurationIfNeeded(excluding: inputTempDuration)
    }

    func validateEditsMade() -> Bool {
        guard let inputTempDuration else { return true }
        return inputTempDuration.temperature != temperature
        || inputTempDuration.units != units
        || Int(inputTempDuration.duration.rounded(.down)) != ((selectedMinutes * 60) + selectedSeconds)
    }
}

private struct AutoTimeRequestEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let step: SingleStep
    @State private var temperature: Double = 20
    @State private var units: UnitTemperature = .celsius
    @State private var editsMade: Bool = false

    let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    init(step: SingleStep) {
        self.step = step
        _temperature = State(initialValue: step.requestedTemperature ?? 20)
        _units = State(initialValue: step.requestedTemperatureUnits)
    }

    var body: some View {
        Form {
            Section("Requested Temperature") {
                HStack {
                    TextField("Requested Temperature", value: $temperature, formatter: formatter)
                        .keyboardType(.decimalPad)
                    Picker("Units", selection: $units) {
                        ForEach([UnitTemperature.celsius, UnitTemperature.fahrenheit], id: \.self) { temperature in
                            Text(temperature.symbol)
                        }
                    }
                    .pickerStyle(.palette)
                }
                Text("Auto Time uses this temperature when no exact preset matches the current timing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            editsMade = validateEditsMade()
        }
        .onChange(of: temperature) { _, _ in
            editsMade = validateEditsMade()
        }
        .onChange(of: units) { _, _ in
            editsMade = validateEditsMade()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .cancel) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .confirm) {
                    step.requestedTemperature = temperature
                    step.requestedTemperatureUnits = units
                    _ = step.refreshAutoTimeDurationIfNeeded()
                    dismiss()
                }
                .disabled(!editsMade)
            }
        }
        .navigationBarBackButtonHidden()
        .navigationTitle("Edit Auto Time Request")
    }

    private func validateEditsMade() -> Bool {
        guard step.requestedTemperature != nil else { return true }
        return step.requestedTemperature != temperature
        || step.requestedTemperatureUnits != units
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
        requestedTemperature: 21,
        requestedTemperatureUnits: .celsius,
        substep: SubstepProcess(title:"Untitled Process", duration:15, gap: 45),
        tempDuration: [
            TemperatureDuration(temperature: 68, units: .fahrenheit, duration: 9.5 * 60),
            TemperatureDuration(temperature: 23, units: .celsius, duration: 10.5 * 60)
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
        requestedTemperature: 23,
        requestedTemperatureUnits: .celsius,
        substep: SubstepProcess(title:"Untitled Process", duration:15, gap: 45),
        tempDuration: [
            TemperatureDuration(temperature: 68, units: .fahrenheit, duration: 9.5 * 60),
            TemperatureDuration(temperature: 23, units: .celsius, duration: 10.5 * 60)
        ]
    )
    TempDurationEditorView(step: step)
}
