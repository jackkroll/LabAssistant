//
//  ChemicalDetailView.swift
//  LabAssistant
//
//  Created by Jack Kroll on 10/31/25.
//

import SwiftUI
import SwiftData

struct ChemicalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var chemical: Chemical

    @State private var newTagTitle: String = ""

    @FocusState private var isEditingCurrent: Bool
    @FocusState private var isEditingMax: Bool

    var body: some View {
        Form {
            Section(header: Text("Basics")) {
                TextField("Nickname", text: $chemical.nickname)
                    .font(.title3)

                Picker("Units", selection: $chemical.units) {
                    // Assuming units is an enum with rawValue
                    ForEach(Chemical.Units.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Capacity")
                            .font(.callout).foregroundStyle(.secondary)
                        Gauge(value: chemical.current, in: 0...chemical.max) {
                            Label {
                                Text("\(Int(chemical.current))/\(Int(chemical.max)) \(chemical.units.rawValue)")
                            } icon: { Image(systemName: "flask") }
                                .labelStyle(.titleOnly)
                        }
                        .gaugeStyle(.linearCapacity)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current Amount")
                            .font(.callout).foregroundStyle(.secondary)
                        HStack {
                            TextField("0", value: $chemical.current, format: .number)
                                .keyboardType(.numberPad)
                                .focused($isEditingCurrent)
                                .onSubmit { normalizeCurrent() }
                                .onChange(of: isEditingCurrent) { _, nowFocused in
                                    if !nowFocused { normalizeCurrent() }
                                }
                            Text(chemical.units.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Max")
                            .font(.callout).foregroundStyle(.secondary)
                        HStack {
                            TextField("0", value: $chemical.max, format: .number)
                                .keyboardType(.numberPad)
                                .focused($isEditingMax)
                                .onSubmit { normalizeMax() }
                                .onChange(of: isEditingMax) { _, nowFocused in
                                    if !nowFocused { normalizeMax() }
                                }
                            Text(chemical.units.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            NavigationLink {
                TagEditorView(appliedTags: $chemical.tags)
                    .navigationTitle(chemical.nickname.appending(" Tags"))
            } label: {
                Image(systemName: "tag.fill")
                Text("Tag Editor")
            }

            Section(header: Text("Expiry")) {
                Toggle(isOn: Binding(
                    get: { chemical.expiryDate != nil },
                    set: { useExpiry in
                        if useExpiry {
                            if chemical.expiryDate == nil { chemical.expiryDate = .now }
                        } else {
                            chemical.expiryDate = nil
                        }
                    }
                )) {
                    Text("Has Expiry Date")
                }

                if let date = chemical.expiryDate {
                    DatePicker("Expiry", selection: Binding(get: { date }, set: { chemical.expiryDate = $0 }), displayedComponents: [.date])
                    SmallDate(date: date, expanded: true)
                }
            }
            Button(role: .destructive) {
                modelContext.delete(chemical)
                try? modelContext.save()
                dismiss()
            } label: {
                Image(systemName: "trash.fill")
                Text("Delete Chemical")
            }
            .buttonStyle(.borderedProminent)
            .buttonSizing(.flexible)
            .fontWeight(.semibold)
        }
    }

    private func normalizeCurrent() {
        if chemical.current.isNaN || chemical.current < 0 { chemical.current = 0 }
        if chemical.current > chemical.max { chemical.current = chemical.max }
    }

    private func normalizeMax() {
        let minimum = max(1, chemical.current)
        if chemical.max.isNaN || chemical.max < minimum { chemical.max = minimum }
    }
}

#Preview {
    // Preview with sample data in memory
    let container = try! ModelContainer(for: Chemical.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let ctx = container.mainContext

    let sample = Chemical(nickname: "Ethanol", max: 500, current: 120)
    sample.units = .ml
    sample.tags = [Tag(title: "Flammable"), Tag(title: "Hazard")]
    sample.expiryDate = Calendar.current.date(byAdding: .month, value: 6, to: .now)

    ctx.insert(sample)

    return NavigationStack { ChemicalDetailView(chemical: sample) }
        .modelContainer(container)
}
