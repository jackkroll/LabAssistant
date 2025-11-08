//
//  ContentView.swift
//  LabAssistant
//
//  Created by Jack Kroll on 9/28/25.
//

import SwiftUI
import SwiftData
import CloudKitSyncMonitor

struct ChemicalStorageView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var syncMonitor = SyncMonitor.default
    @Query private var items: [Chemical]
    @State var showAddChemicalSheet : Bool = false
    @State var displayCloudStatusDetailSheet : Bool = false
    var body: some View {
        NavigationStack {
            VStack {
                if items.count == 0 {
                    ContentUnavailableView {
                        Label("No chemicals saved", systemImage: "flask")
                    } description: {
                        Text("Create a new one!")
                    }
                }
                else {
                    List {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                ChemCard(chem: item)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                    
                    .scrollContentBackground(.hidden)
                }
                
                
            }
            .sheet(isPresented: $showAddChemicalSheet) {
                AddChemicalSheet()
                    .presentationDetents([.large])
                    .interactiveDismissDisabled()
            }
            .toolbar {
                ToolbarItem {
                    Image(systemName: syncMonitor.syncStateSummary.symbolName)
                        .foregroundColor(syncMonitor.syncStateSummary.symbolColor)
                        .animation(.easeInOut, value: syncMonitor.syncStateSummary.symbolColor)
                        .animation(.easeInOut, value: syncMonitor.syncStateSummary.symbolName)
                }
                ToolbarSpacer(.flexible)
                ToolbarItem{
                    Button{
                        showAddChemicalSheet = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: Chemical.self) { chemical in
                ChemicalDetailView(chemical: chemical)
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

struct TagRender: View {
    @State var tag: Tag
    
    var body: some View {
        Text(tag.title)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tag.swiftColor().opacity(0.25))
            .foregroundStyle(tag.swiftColor())
            .clipShape(Capsule())
    }
}
struct SmallDate: View {
    var date: Date
    var expanded = false
    
    var body: some View {
        if Date.now < date {
            let color = cardColorWarning(distance: Date.now.distance(to: date))
            Text(date, style: .relative)
                .padding(10)
                .frame(maxWidth: expanded ? .infinity : nil)
                .background(color.opacity(0.25))
                .foregroundStyle(color)
                .clipShape(Capsule())
                .font(.callout)
                .fontWeight(.semibold)
        }
        else {
            Text("Expired")
                .padding(10)
                .frame(maxWidth: expanded ? .infinity : nil)
                .background(.red.opacity(0.25))
                .foregroundStyle(.red)
                .clipShape(Capsule())
                .font(.callout)
                .fontWeight(.semibold)
                
        }
    }
    
    func cardColorWarning(distance: TimeInterval) -> Color {
        if distance < 86400 * 3 {
            return Color.red
        }
        else if distance < 86400 * 7 {
            return Color.orange
        }
        else if distance < 86400 * 14 {
            return Color.yellow
        }
        else {
            return Color.green
        }
    }
}

struct ChemCard: View {
    @State var chem: Chemical
    var body: some View {
        VStack {
            HStack {
                Text(chem.nickname)
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                
                if (chem.expiryDate != nil) {
                    SmallDate(date: chem.expiryDate!)
                }
            }
            if chem.tags != nil {
                HStack{
                    ForEach(chem.tags!) { tag in
                        TagRender(tag: tag)
                    }
                    Spacer()
                }
            }
            Gauge(value: chem.current, in: 0...chem.max) {
                /*
                Label {
                    Text("\(chem.current)\(chem.units.rawValue) remaining")
                } icon: {
                    Image(systemName: "flask")
                }
                .labelStyle(.n)
                 */
            }
            .gaugeStyle(.linearCapacity)
        }
    }
}

#Preview("Sample Chemicals") {
    // Create an in-memory container for previews
    let container = try! ModelContainer(for: Chemical.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    // Build some sample data
    let water = Chemical(nickname: "Water", max: 1000, current: 850)
    water.units = .ml
    water.tags = [Tag(title: "Safe"), Tag(title: "Common")]
    water.expiryDate = Calendar.current.date(byAdding: .day, value: 365, to: .now)

    let ethanol = Chemical(nickname: "Ethanol", max: 500, current: 120)
    ethanol.units = .ml
    ethanol.tags = [Tag(title: "Flammable"), Tag(title: "Hazard")]
    ethanol.expiryDate = Calendar.current.date(byAdding: .month, value: 6, to: .now)

    let hcl = Chemical(nickname: "HCl", max: 250, current: 40)
    hcl.units = .ml
    hcl.tags = [Tag(title: "Corrosive"), Tag(title: "Acid")]
    hcl.expiryDate = Calendar.current.date(byAdding: .day, value: -10, to: .now) // expired

    // Insert into the preview context
    context.insert(water)
    context.insert(ethanol)
    context.insert(hcl)

    return ChemicalStorageView()
        .modelContainer(container)
}
