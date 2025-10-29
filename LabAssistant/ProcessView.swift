//
//  ProcessView.swift
//  LabAssistant
//
//  Created by Jack Kroll on 10/26/25.
//

import SwiftUI
import SwiftData

struct ProcessView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var processes: [DevProcess]
    
    @State var addProcessSheet: Bool = false
    var body: some View {
        NavigationStack {
            VStack {
                if processes.count == 0 {
                    ContentUnavailableView {
                        Label("No processes saved", systemImage: "flask")
                    } description: {
                        Text("Create a new one!")
                    }
                }
                else {
                    ForEach(processes){ process in
                            GroupBox {
                                VStack {
                                    HStack {
                                        Text(process.nickname)
                                            .font(.title)
                                            .fontWeight(.bold)
                                        Spacer()
                                        Text(process.steps.count.description + " steps")
                                        if process.estTime != nil {
                                            Text(Int(process.estTime!/60).description + " min")
                                        }
                                    }
                                    HStack {
                                        NavigationLink(value: process) {
                                            Image(systemName: "play.circle.fill")
                                                .symbolRenderingMode(.hierarchical)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 40, height: 40)
                                        }
                                        
                                        Spacer()
                                        Button(role:.destructive) {
                                            modelContext.delete(process)
                                            try? modelContext.save()
                                        } label: {
                                            Image(systemName: "trash.circle.fill")
                                                .symbolRenderingMode(.hierarchical)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 40, height: 40)
                                        }
                                    }
                                }
                        }
                    }
                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem {
                    Button{
                        addProcessSheet = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: DevProcess.self) { process in
                DevelopView(process: process)
            }
        }
        
        .sheet(isPresented: $addProcessSheet) {
            AddProcessSheet()
        }
        
    }
}

#Preview {
    // In-memory SwiftData container for previews
    let container = try! ModelContainer(
        for: DevProcess.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    // Build an agitation substep process: initial 30s, then 10s each minute
    let agitation = SubstepProcess(title: "Agitation", duration: 10, gap: 50)

    // Build steps using SingleStep, filling all properties
    let steps: [SingleStep] = [
        SingleStep(
            title: "Prepare Chemicals",
            index: 0,
            notes: "Mix Ilfotec DD-X 1+4 at 20°C. Prepare stop and fixer.",
            autoAdvance: true,
            associatedChemicals: [],
            totalDuration: nil,
            substep: nil
        ),
        SingleStep(
            title: "Develop",
            index: 1,
            notes: "Total 9:00. Initial 30s agitation, then 10s each minute.",
            autoAdvance: false,
            associatedChemicals: [],
            totalDuration: 9 * 60,
            substep: agitation
        ),
        SingleStep(
            title: "Stop Bath",
            index: 2,
            notes: "Ilfostop 1+19, 30s continuous agitation.",
            autoAdvance: true,
            associatedChemicals: [],
            totalDuration: 30,
            substep: nil
        ),
        SingleStep(
            title: "Fix",
            index: 3,
            notes: "Rapid Fixer 1+4, 5 min. Agitate first 30s, then 10s each minute.",
            autoAdvance: false,
            associatedChemicals: [],
            totalDuration: 5 * 60,
            substep: agitation
        ),
        SingleStep(
            title: "Wash",
            index: 4,
            notes: "Running water 5–10 min (Ilford method acceptable).",
            autoAdvance: true,
            associatedChemicals: [],
            totalDuration: 7 * 60,
            substep: nil
        ),
        SingleStep(
            title: "Final Rinse",
            index: 5,
            notes: "Photo-Flo per instructions. Hang to dry.",
            autoAdvance: true,
            associatedChemicals: [],
            totalDuration: 60,
            substep: nil
        )
    ]

    let ilfordBW = DevProcess(
        nickname: "HP5+ in DD-X",
        notes: """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean et consectetur purus. Ut ac metus a dui hendrerit tempus a a sem. Nullam pharetra blandit urna, nec feugiat lectus sollicitudin eu. Pellentesque vehicula congue dui dictum iaculis. Aliquam ac dolor vel nisl luctus interdum ac eget lacus. Nam maximus quam quis quam tristique ornare. Aliquam sit amet aliquam lectus. Suspendisse neque ante, dignissim a est id, dignissim lobortis elit. Vivamus id ante consequat, mattis mauris id, finibus nibh. Mauris volutpat ante leo, sit amet gravida diam vulputate imperdiet. Sed porta risus ac est interdum, sit amet ullamcorper magna sodales. Ut sapien mi, euismod eget mauris sed, gravida tempor purus. Phasellus tempor, erat ut ultrices vestibulum, tortor nisl efficitur sem, vel faucibus est tortor ac arcu.
        """,
        steps: steps
    )

    context.insert(ilfordBW)
    try? context.save()

    return ProcessView()
        .modelContainer(container)
}
