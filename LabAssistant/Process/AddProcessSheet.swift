import SwiftUI
import SwiftData

struct AddProcessSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    
    @State private var process: DevProcess = .init(nickname: "", steps: [])
    var body: some View {
        if process.steps == nil {
            
        }
        else {
            NavigationStack {
                Form {
                    Section("Details") {
                        TextField("Process name", text: $process.nickname)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                        
                        TextField("Notes (optional)", text: $process.notes, axis: .vertical)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Section("Steps") {
                        if process.sortedSteps.isEmpty {
                            ContentUnavailableView("No steps", systemImage: "list.bullet", description: Text("Tap Add Step"))
                        } else {
                            
                            ForEach($process.sortedSteps) { step in
                                let stepID = step.wrappedValue.id
                                let stepPosition = process.stepPosition(for: stepID) ?? 0
                                NavigationStack {
                                    HStack {
                                        TextField("Step title", text: step.title)
                                            .textInputAutocapitalization(.words)
                                            .autocorrectionDisabled()
                                        
                                        NavigationLink(value: step.wrappedValue) {
                                            Image(systemName: "pencil.circle.fill")
                                                .symbolRenderingMode(.hierarchical)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 30, height: 30)
                                        }
                                        .navigationLinkIndicatorVisibility(.hidden)
                                        .buttonBorderShape(.capsule)
                                        .buttonStyle(.borderedProminent)
                                        
                                        Button {
                                            withAnimation {
                                                process.moveStep(withID: stepID, by: -1)
                                                save()
                                            }
                                        }
                                        label: {
                                            Image(systemName: "arrow.up.circle.fill")
                                                .symbolRenderingMode(.hierarchical)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 30, height: 30)
                                        }
                                        .buttonStyle(.borderless)
                                        .disabled(stepPosition == 0)
                                        
                                        
                                        Button {
                                            withAnimation {
                                                process.moveStep(withID: stepID, by: 1)
                                                save()
                                            }
                                        } label: {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .symbolRenderingMode(.hierarchical)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 30, height: 30)
                                        }
                                        .buttonStyle(.borderless)
                                        .disabled(stepPosition >= process.sortedSteps.count - 1)
                                        
                                        Spacer()
                                        Button(role: .destructive) {
                                            withAnimation {
                                                process.removeStep(withID: stepID)
                                                save()
                                            }
                                        } label: {
                                            Image(systemName: "trash.circle.fill")
                                                .symbolRenderingMode(.hierarchical)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(maxWidth: 40)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    .navigationDestination(for: SingleStep.self) { step in
                                        if let binding = binding(for: step) {
                                            StepDetailView(step: binding)
                                        } else {
                                            // Fallback if binding can't be found
                                            Text("Step not found")
                                        }
                                    }
                                }
                                
                            }
                            
                        }
                        
                        Button {
                            withAnimation {
                                process.appendUntitledStep()
                            }
                            save()
                        } label: {
                            Label("Add Step", systemImage: "plus.circle.fill")
                        }
                    }
                }
                .navigationTitle("New Process")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm){
                            dismiss()
                            modelContext.insert(process)
                            try? modelContext.save()
                        }
                        .disabled(process.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                
            }
        }
    }
    
    func save() {
        try? modelContext.save()
    }
    
    private func binding(for step: SingleStep) -> Binding<SingleStep>? {
        guard process.sortedSteps.contains(where: { $0.id == step.id }) else { return nil }

        let stepID = step.id
        return Binding(
            get: {
                guard let idx = process.sortedSteps.firstIndex(where: { $0.id == stepID }) else {
                    return step
                }
                return process.sortedSteps[idx]
            },
            set: { newValue in
                guard let idx = process.sortedSteps.firstIndex(where: { $0.id == stepID }) else { return }
                process.sortedSteps[idx] = newValue
            }
        )
    }
}

#Preview {
    // Build an explicit schema to avoid type inference ambiguity in previews
    let schema = Schema([Chemical.self, DevProcess.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    
    let context = container.mainContext
    let process = DevProcess(nickname: "", notes: "", steps: [])
    context.insert(process)
    
    return AddProcessSheet()
        .modelContainer(container)
}
