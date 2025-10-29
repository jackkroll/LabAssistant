//
//  ContentView.swift
//  LabAssistant
//
//  Created by Jack Kroll on 9/28/25.
//

import SwiftUI
import SwiftData

struct ChemicalStorageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Chemical]
    @State var showAddChemicalSheet : Bool = false

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
                            NavigationLink {
                                VStack {
                                    Text(item.nickname)
                                    Gauge(value: item.current, in: 0...item.max) {
                                        Label("\(item.current)/\(item.max)", systemImage: "flask")
                                    }
                                }
                            } label: {
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
                    Button{
                        showAddChemicalSheet = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Chemical(nickname: "Water", max: 100, current: 80)
            newItem.tags.append(Tag(title: "Safe"))
            newItem.expriryDate = .distantPast
            modelContext.insert(newItem)
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
    var body: some View {
        if Date.now < date {
            Text(date, style: .relative)
                .padding(10)
                .background(.gray.opacity(0.25))
                .foregroundStyle(.gray)
                .clipShape(Capsule())
                .font(.callout)
                .fontWeight(.semibold)
        }
        else {
            Text("Expired")
                .padding(10)
                .background(.red.opacity(0.25))
                .foregroundStyle(.red)
                .clipShape(Capsule())
                .font(.callout)
                .fontWeight(.semibold)
        }
    }
}

struct ChemCard: View {
    @State var chem: Chemical
    var body: some View {
        VStack {
            HStack {
                Text(chem.nickname)
                    .font(.title3)
                Spacer()
                ForEach(chem.tags) { tag in
                    TagRender(tag: tag)
                }
                if (chem.expriryDate != nil) {
                    SmallDate(date: chem.expriryDate!)
                }
            }
            Gauge(value: chem.current, in: 0...chem.max) {
                Label {
                    Text("\(chem.current)\(chem.units.rawValue) remaining")
                } icon: {
                    Image(systemName: "flask")
                }
                .labelStyle(.titleOnly)
            }
            .gaugeStyle(.linearCapacity)
        }
    }
}

#Preview {
    ChemicalStorageView()
        .modelContainer(for: Chemical.self, inMemory: true)
}
