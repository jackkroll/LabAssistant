//
//  AddChemicalSheet.swift
//  LabAssistant
//
//  Created by Jack Kroll on 9/28/25.
//

import SwiftUI
import SwiftData

struct AddChemicalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var nickname: String = ""
    @State private var hasExpiry: Bool = false
    @State private var expiryDate: Date = .now
    @State private var maxAmount: Double? = nil
    @State private var currentAmount: Double? = nil
    @State private var notes: String = ""
    @State private var units: Chemical.Units = .ml
    @State private var tags: [Tag] = []
    @State private var newTagTitle: String = ""
    @Namespace private var tagNamespace
    @State private var usesOtherChemical: Bool = false
    
    @Query(filter: #Predicate { $0.current > 0},sort: [SortDescriptor(\Chemical.nickname, order: .forward)]) private var allChemicals: [Chemical]
    @State private var isMixtureExpanded: Bool = false
    @State private var selectedComponent: Chemical? = nil
    @State private var selectedComponentAmount: Double? = nil
    @State private var mixtureComponents: [(chemical: Chemical, amount: Double)] = []
    
    private var isSaveDisabled: Bool {
        // All cases that aren't allowed
        maxAmount == nil ||
        currentAmount == nil ||
        nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        maxAmount! <= 0 ||
        currentAmount! < 0 ||
        currentAmount! > maxAmount! ||
        mixtureComponents.contains { $0.amount <= 0 } ||
        !(mixtureComponents.allSatisfy( { $0.chemical.current >= $0.amount }) )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $nickname)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        
                    
                    Picker("Units", selection: $units) {
                        ForEach(Chemical.Units.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    
                    HStack {
                        Text("Max Capacity")
                        Spacer()
                        TextField("Max", value: $maxAmount, format: .number.precision(.fractionLength(0...3)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Current Capacity")
                        Spacer()
                        TextField("Current", value: $currentAmount, format: .number.precision(.fractionLength(0...3)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Details")
                }
                
                Section {
                    Toggle("Has expiry date", isOn: $hasExpiry)
                        .animation(.default, value: hasExpiry)
                    
                    if hasExpiry {
                        DatePicker("Expiry", selection: $expiryDate, in: Date.now..., displayedComponents: .date)
                    }
                } header: {
                    Text("Expiration")
                }
                
                Section {
                    DisclosureGroup(isExpanded: $isMixtureExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            // Picker to choose an existing chemical (excluding the one being created)
                            Picker("Component", selection: Binding(
                                get: { selectedComponent?.id },
                                set: { newID in
                                    selectedComponent = allChemicals.first { $0.id == newID }
                                }
                            )) {
                                Text("Select a chemical").tag(Optional<UUID>.none)
                                ForEach(allChemicals) { chem in
                                    Text(chem.nickname).tag(Optional(chem.id))
                                }
                            }

                            HStack {
                                Text("Amount to deduct")
                                Spacer()
                                TextField("Amount", value: $selectedComponentAmount, format: .number.precision(.fractionLength(0...3)))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                            }
                            .accessibilityLabel("Amount to deduct from selected component")

                            Button {
                                addSelectedComponent()
                            } label: {
                                Label("Add Component", systemImage: "plus")
                                    .labelStyle(.titleOnly)
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .disabled(selectedComponent == nil || (selectedComponentAmount ?? 0) <= 0 || selectedComponentAmount ?? .infinity > selectedComponent!.current)

                            if !mixtureComponents.isEmpty {
                                Divider()
                                Text("Components in mixture")
                                    .font(.headline)
                                ForEach(Array(mixtureComponents.enumerated()), id: \.offset) { index, comp in
                                    HStack {
                                        TagRender(tag: Tag(title: comp.chemical.nickname))
                                        Spacer()
                                        let amountText = comp.amount.formatted(.number.precision(.fractionLength(0...3)))
                                        Text("\(amountText) \(units.rawValue)")
                                            .foregroundStyle(.secondary)
                                        Button(role: .destructive) {
                                            removeComponent(at: index)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Label("Create Mixture", systemImage: "drop.halffull")
                            .labelStyle(.titleOnly)
                    }
                } footer: {
                    Text("Select existing chemicals and how much to deduct from them when this mixture is created.")
                }
                
                /*
                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                } header: {
                    Text("Notes")
                }
                */
                Section {
                    // Preview Tags
                    if tags.isEmpty {
                        Text("No tags yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags, id: \.title) { tag in
                                    HStack(spacing: 4) {
                                        TagRender(tag: tag)
                                            .matchedGeometryEffect(id: tagKey(tag.title), in: tagNamespace)
                                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                                        Button {
                                            removeTag(tag)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .imageScale(.medium)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .animation(.snappy, value: tags)
                            .padding(.vertical, 4)
                        }
                    }
                    // Add preset
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(PresetTag.allCases) { preset in
                                let visualTag = presetTag(preset: preset)
                                if !tags.contains(where: { $0 == visualTag }) {
                                    HStack(spacing: 4) {
                                        TagRender(tag: visualTag)
                                            .matchedGeometryEffect(id: tagKey(visualTag.title), in: tagNamespace)
                                            .transition(.opacity)
                                        Button {
                                            addPreset(tag: visualTag)
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .imageScale(.medium)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.secondary)
                                    }
                                    .transition(.opacity)
                                }
                            }
                            if allPresetsGone() {
                                Text("No more preset tags, add your own!")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .transition(.opacity)
                            }
                            
                        }
                        .animation(.snappy, value: tags)
                    }
                    // Add custom
                    HStack(spacing: 8) {
                        TextField("Add a tag", text: $newTagTitle)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onSubmit { addTag() }
                        Button {
                            addTag()
                        } label: {
                            Label("Add", systemImage: "plus.circle.fill")
                                .labelStyle(.iconOnly)
                        }
                        .disabled(newTagTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                     
                } header: {
                    Text("Tags")
                } footer: {
                    Text("Presets to help you organize your chemicals.")
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .submitLabel(.done)
            .toolbar{
                ToolbarItem(placement: .confirmationAction){
                    Button(role: .confirm) {
                        let chemicalToAdd = newChemical()
                        if chemicalToAdd != nil {
                            // Persist to SwiftData
                            modelContext.insert(chemicalToAdd!)
                            for (chemical,amount) in mixtureComponents {
                                chemical.current-=amount
                                // Prevent negative amounts, but this case is save disabled
                                if chemical.current < 0 {
                                    chemical.current = 0
                                }
                            }
                            do {
                                try modelContext.save()
                                
                            } catch {
                                modelContext.delete(chemicalToAdd!)
                            }
                        }
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
                ToolbarItem(placement: .cancellationAction){
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
            }
            
        }
        
        
    }
    
    private func addSelectedComponent() {
        guard let chem = selectedComponent, let amt = selectedComponentAmount, amt > 0 else { return }
        // Prevent duplicates: if exists, update amount by summing
        if let idx = mixtureComponents.firstIndex(where: { $0.chemical == chem }) {
            withAnimation(.bouncy) {
                mixtureComponents[idx].amount += amt
            }
        } else {
            withAnimation(.bouncy) {
                mixtureComponents.append((chemical: chem, amount: amt))
            }
        }
        // reset inputs
        selectedComponent = nil
        selectedComponentAmount = nil
    }

    private func removeComponent(at index: Int) {
        guard mixtureComponents.indices.contains(index) else { return }
        mixtureComponents.remove(at: index)
    }
    
    func allPresetsGone() -> Bool {
        var presetsFound = 0
        let presetTitles : [String] = ["Powder", "Liquid", "Working Solution"]
        for tag in tags {
            if presetTitles.contains(tag.title) {
                presetsFound+=1
                if presetsFound >= PresetTag.allCases.count {
                    return true
                }
            }
        }
        return false
    }
    
    func newChemical() -> Chemical? {
        if isSaveDisabled {
            return nil
        }
        // Build optional expiry
        let expiry: Date? = hasExpiry ? expiryDate : nil
        let chemical = Chemical(
            nickname: nickname,
            expriryDate: expiry,
            max: maxAmount!,
            current: currentAmount!,
            notes: notes,
            tags: tags,
            units: units
        )
        return chemical
    }
    
    private func presetTag(preset: PresetTag) -> Tag {
        let tag : Tag
        switch preset {
        case .workingSolution:
            tag = Tag(title: "Working Solution")
            tag.storedColor = .green
        case .liquid:
            tag = Tag(title: "Liquid")
            tag.storedColor = .blue
        case .powder:
            tag = Tag(title: "Powder")
            tag.storedColor = .indigo
        }
        return tag
    }
    private enum PresetTag : String, CaseIterable, Identifiable{
        var id: String {rawValue}
        case workingSolution
        case liquid
        case powder
    }
    
    private func tagKey(_ title: String) -> String {
        "tag-" + title.lowercased()
    }
    
    private func addPreset(tag: Tag) {
        withAnimation(.bouncy) {
            tags.append(tag)
        }
    }
    
    private func addTag(title inputTagTitle: String? = nil) {
        let trimmed: String
        if inputTagTitle != nil {
            trimmed = inputTagTitle!.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        else {
            trimmed = newTagTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !trimmed.isEmpty else { return }
        // Prevent duplicates (case-insensitive)
        if !tags.contains(where: { $0.title.compare(trimmed, options: .caseInsensitive) == .orderedSame }) {
            withAnimation(.bouncy) {
                tags.append(Tag(title: trimmed))
            }
        }
        newTagTitle = ""
    }

    private func removeTag(_ tag: Tag) {
        withAnimation(.bouncy) {
            tags.removeAll { $0.title.compare(tag.title, options: .caseInsensitive) == .orderedSame }
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Chemical.self, configurations: config)
        let context = container.mainContext
        // Seed a few example chemicals for the mixture picker
        let sample1 = Chemical(nickname: "Water", expriryDate: nil, max: 1000, current: 750, notes: "", tags: [], units: .ml)
        let sample2 = Chemical(nickname: "Ethanol", expriryDate: nil, max: 500, current: 200, notes: "", tags: [], units: .ml)
        context.insert(sample1)
        context.insert(sample2)
        return AddChemicalSheet()
            .modelContainer(container)
    } catch {
        return AddChemicalSheet()
            .modelContainer(for: Chemical.self, inMemory: true)
    }
}

// MARK: - Notes
// This view expects the `Chemical` model to provide:
// 1) An identifiable/persistent identifier (`persistentModelID` or `_persistentIdentifier`) to reference components.
// 2) A nested `Component` value type with fields: `sourceID`, `amount`, and `units` compatible with `Chemical.Units`.
// If your `Chemical` model differs, adjust the mapping in `newChemical()` accordingly.

