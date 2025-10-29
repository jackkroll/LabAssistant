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
                            .keyboardType(.numberPad)
                        Spacer()
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                    .onChange(of: durationMinutes) { _, newValue in
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

            Section("Associated Chemicals") {
                if allChemicals.isEmpty {
                    ContentUnavailableView("No chemicals in library", systemImage: "testtube.2", description: Text("Add chemicals to your library to use them here."))
                } else {
                    Picker("Add from library", selection: Binding<PersistentIdentifier?>(
                        get: { selectedChemicalID },
                        set: { newValue in
                            selectedChemicalID = newValue
                            guard let id = newValue, let chem = allChemicals.first(where: { $0.id == id }) else { return }
                            if !step.associatedChemicals.contains(where: { $0.id == chem.id }) {
                                step.associatedChemicals.append(chem)
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
                    if step.associatedChemicals.isEmpty == false {
                        ForEach(step.associatedChemicals, id: \.self) { chem in
                            Text(chem.nickname)
                        }
                        .onDelete { indices in
                            step.associatedChemicals.remove(atOffsets: indices)
                        }
                    } else {
                        ContentUnavailableView("No chemicals selected", systemImage: "testtube.2", description: Text("Pick from your chemicals library above."))
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
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { isEditingSubstep = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { isEditingSubstep = false }
                            }
                        }
                } else {
                    Text("No substep to edit")
                }
            }
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
        title: "",
        index: 0,
        notes: "",
        autoAdvance: true,
        associatedChemicals: [Chemical(nickname: "NaCl", max: 100, current: 50)],
        totalDuration: 600,
        substep: SubstepProcess(title:"Untitled", duration:15, gap: 45)
    )
    NavigationStack {
        StepDetailView(step: $step)
    }
}
