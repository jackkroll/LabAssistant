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
    @State private var autoTime: Bool = false
    @State private var autoTimeDetails: Bool = false
    @State private var autoTimeAdditionalInfo: Bool = false
    @State private var developerBehavior: DeveloperBehavior?
    
    private enum DeveloperBehavior {
        case slow, normal, fast
        enum InvalidType {
            case high, low
        }
        case invalid(speed: InvalidType)
    }
    @State private var editsMade: Bool = false
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    private var isTemperatureInSupportedRange: Bool {
        guard let temperature else { return false }
        return SingleStep.isTemperatureInEstimateRange(Measurement(value: temperature, unit: units))
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
        _temperatureDenoted = State(initialValue: inputTempDuration.map { $0.temperature != nil } ?? true)
    }
    
    var body: some View {
        VStack {
            Form {
                    switch developerBehavior {
                    case .slow:
                        EmptyView()
                    case .normal:
                        EmptyView()
                    case .fast:
                        EmptyView()
                    case .invalid(let speed):
                        DisclosureGroup {
                            Text("Ensure your other presets contain the correct time & temperature settings. Auto time utilizes them to calculate the correct temperature, and detected that it is unusually \(speed)")
                        } label: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .symbolRenderingMode(.multicolor)
                            Text("Calculated temperature response is unusually \(speed)")
                        }
                    case nil:
                        EmptyView()
                    }
                    
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
                    
                    if autoTime && !isTemperatureInSupportedRange {
                        DisclosureGroup {
                            Text("Keep the temperature within 16ºC and 36ºC to use this feature")
                        } label: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.secondary)
                            Text("Auto Time Unavailable")
                        }
                    }
                    
                    
                    
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
                        .overlay {
                            if autoTime {
                                ZStack {
                                    Image(systemName: "bolt.badge.clock.fill")
                                        .scaleEffect(1.5)
                                    Color.secondary.opacity(0.2)
                                        .clipShape(ConcentricRectangle(corners: .concentric, isUniform: true))
                                }
                                .animation(.easeInOut, value: autoTime)
                            }
                        }
                        .pickerStyle(.wheel)
                        .disabled(autoTime)
                    }
                    .listRowSeparator(.hidden)
                    Toggle("Auto time", isOn: $autoTime)
                        .disabled(!canEstimateTime)
                        .listRowSeparator(.hidden)
                    AutoTimeDisclosure(
                        step: step,
                        temperature: temperature,
                        units: units,
                        autoTimeDetails: $autoTimeDetails
                    )
                    .listRowSeparator(.hidden)
                    AutoTimeAdditionalInfoDisclosure(isExpanded: $autoTimeAdditionalInfo)
                        .listRowSeparator(.hidden)
                }
            }
            .onChange(of: autoTime) { _, new in
                if new, let temperature = temperature {
                    applyAutoTime(at: Measurement(value: temperature, unit: units))
                }
            }
            .onChange(of: temperature) { _, new in
                if autoTime, let new = new {
                    applyAutoTime(at: Measurement(value: new, unit: units))
                }
            }
            .onChange(of: units) { old, new in
                if let oldTemp = temperature {
                    temperature = Measurement(value: oldTemp, unit: old).converted(to: new).value
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
    
    var currentTemperatureMeasurement: Measurement<UnitTemperature>? {
        guard let temperature else { return nil }
        return Measurement(value: temperature, unit: units)
    }
    
    var canEstimateTime: Bool {
        guard let currentTemperatureMeasurement else { return false }
        return step.canEstimateTime(at: currentTemperatureMeasurement)
    }
    
    func applyAutoTime(at newTime: Measurement<UnitTemperature>) {
        let calculatedTime = step.timeEstimate(at: newTime)
        if let estK = calculatedTime?.estimatedK {
            developerBehavior = approximateDeveloperBehavior(atK: estK)
        }
        if let estTime  = calculatedTime?.duration {
            withAnimation {
                selectedMinutes = Int(estTime.rounded() / 60)
                selectedSeconds = Int(estTime.rounded().truncatingRemainder(dividingBy: 60))
            }
        } else {
            //withAnimation {
            //    autoTime = false
            //}
        }
    }
    private func approximateDeveloperBehavior(atK kVal: Double) -> DeveloperBehavior? {
        if (0.055...0.105).contains(kVal) {
            if (0.055...0.070).contains(kVal) {
                return .slow
            }
            else if (0.070...0.085).contains(kVal){
                return .normal
            }
            else if (0.085...0.105).contains(kVal){
                return .fast
            }
        }
        else {
            if kVal > 0.105 {
                return .invalid(speed: .high)
            }
            else {
                return .invalid(speed: .low)
            }
        }
        return nil
    }
    func validateEditsMade() -> Bool {
        guard let inputTempDuration else { return true }
        return inputTempDuration.temperature != temperature
        || inputTempDuration.units != units
        || Int(inputTempDuration.duration.rounded(.down)) != ((selectedMinutes * 60) + selectedSeconds)
    }
    private struct RadioStatus: View {

        let value: Bool

        var body: some View {

            Image(systemName: value ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(value ? .green : .secondary)

        }
    }
    
    private struct AutoTimeDisclosure: View {
        let step: SingleStep
        let temperature: Double?
        let units: UnitTemperature
        @Binding var autoTimeDetails: Bool

        private var hasEnoughPresets: Bool {
            step.temperatureEstimatePresetCount >= 2
        }

        private var isTemperatureInSupportedRange: Bool {
            guard let temperature else { return false }
            return SingleStep.isTemperatureInEstimateRange(Measurement(value: temperature, unit: units))
        }

        private var hasPresetTemperatureRange: Bool {
            step.hasTemperatureEstimatePresetRange
        }

        var body: some View {
            DisclosureGroup(isExpanded: $autoTimeDetails) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("At least 2 existing presets")
                        Spacer()
                        RadioStatus(value: hasEnoughPresets)
                    }
                    HStack {
                        Text("Temperature within 16ºC and 36ºC")
                        Spacer()
                        RadioStatus(value: isTemperatureInSupportedRange)
                    }
                    HStack {
                        Text("Existing presets have a range of 2ºC")
                        Spacer()
                        RadioStatus(value: hasPresetTemperatureRange)
                    }
                }
            } label: {
                Text("Requirements")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 5)
            }
            .font(.callout)
        }
    }

    private struct AutoTimeAdditionalInfoDisclosure: View {
        @Binding var isExpanded: Bool

        var body: some View {
            DisclosureGroup(isExpanded: $isExpanded) {
                Text("Conversions are approximate and based on your existing presets. For important work always reference official data sheets")
            } label: {
                Text("Additional Information")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 5)
            }
            .font(.callout)
        }
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
