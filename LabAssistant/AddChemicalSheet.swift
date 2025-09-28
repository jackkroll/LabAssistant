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
    @State private var maxAmount: Double = 100
    @State private var currentAmount: Double = 0
    @State private var notes: String = ""
    @State private var units: Chemical.Units = .ml
    @State private var tags: [Tag] = []
    @State private var newTagTitle: String = ""
    
    private var isSaveDisabled: Bool {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        maxAmount <= 0 ||
        currentAmount < 0 ||
        currentAmount > maxAmount
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
                        DatePicker("Expiry", selection: $expiryDate, displayedComponents: .date)
                    }
                } header: {
                    Text("Expiration")
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
                            .padding(.vertical, 4)
                        }
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
                    // Add preset
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(PresetTag.allCases) { preset in
                                if !tags.contains(where: { $0 == presetTag(preset: preset)}) {
                                    HStack(spacing: 4) {
                                        TagRender(tag: presetTag(preset: preset))
                                            .transition(.opacity)
                                        Button {
                                            addPreset(tag: presetTag(preset: preset))
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .imageScale(.medium)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.secondary)
                                    }
                                    .disabled(tags.contains(where: { $0 == presetTag(preset: preset)}))
                                    .transition(.opacity)
                                    .animation(.bouncy, value: tags.contains(where: { $0 == presetTag(preset: preset)}))
                                }
                            }
                        }
                    }
                     
                } header: {
                    Text("Tags")
                } footer: {
                    Text("Presets to help you organize your chemicals.")
                }
            }
            
        }
        
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
    
    private func addPreset(tag: Tag) {
        tags.append(tag)
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
            tags.append(Tag(title: trimmed))
        }
        newTagTitle = ""
    }

    private func removeTag(_ tag: Tag) {
        tags.removeAll { $0.title.compare(tag.title, options: .caseInsensitive) == .orderedSame }
    }
}

#Preview {
    AddChemicalSheet()
        .modelContainer(for: Chemical.self, inMemory: true)
}
