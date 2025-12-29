//
//  PresetView.swift
//  LabAssistant
//
//  Created by Jack Kroll on 10/29/25.
//

import SwiftUI
import SwiftData
import CloudKit

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
    steps: steps
)

struct PresetView: View {
    @Environment(\.modelContext) private var modelContext
    let publicDB = CKContainer(identifier: "iCloud.icloud.JackKroll.LabAssistant").publicCloudDatabase
    @Query private var ownProcesses: [DevProcess]
    @State private var fetchedProcesses: [DevProcess] = []
    @State private var showUploadSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack {
                    if fetchedProcesses.isEmpty {
                        ContentUnavailableView("Cannot Fetch Presets", systemImage: "wifi.slash")
                    }
                    ForEach(fetchedProcesses) { process in
                        DownloadCard(process: process, downloaded: cloudModelExistsLocally(process: process))
                            .padding()
                    }
                    
                }
            }
            .onAppear {
                fetchFromPublicDB()
            }
            .refreshable {
                fetchFromPublicDB()
            }
            .sheet(isPresented: $showUploadSheet) {
                NavigationStack {
                    UploadSheet()
                }
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        showUploadSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .navigationDestination(for: DevProcess.self) { process in
                    DevelopView(process: process)
            }
        }
        
    }
    
    private func cloudModelExistsLocally(process: DevProcess) -> Bool {
        for localProcess in ownProcesses {
            if localModelSimilarToCloud(local: localProcess, cloud: process) { return true}
        }
        return false
    }
    
    private func localModelSimilarToCloud(local: DevProcess, cloud: DevProcess) -> Bool {
        return (local.nickname == cloud.nickname) && (local.notes == cloud.notes) && stepsSimilar(local: local.sortedSteps, cloud: cloud.sortedSteps)
    }
    
    private func stepsSimilar(local: [SingleStep], cloud: [SingleStep]) -> Bool {
        if local.count != cloud.count { return false }
        for step in zip(local, cloud) {
            if step.0.totalDuration != step.1.totalDuration { return false }
            if step.0.substep?.duration != step.1.substep?.duration { return false }
            if step.0.autoAdvance != step.1.autoAdvance { return false }
        }
        return true
    }
    

    
    private func fetchFromPublicDB() {
        let query = CKQuery(recordType: "DevProcess", predicate: NSPredicate(format: "isApproved == TRUE"))
        
        func handlePage(_ query: CKQuery, cursor: CKQueryOperation.Cursor?) {
            if let cursor = cursor {
                publicDB.fetch(withCursor: cursor, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
                    switch result {
                    case .failure(let error):
                        print("CloudKit fetch error: \(error)")
                    case .success(let page):
                        let records = page.matchResults.compactMap { _, result in
                            try? result.get()
                        }
                        let built = records.compactMap { DevProcess(record: $0) }
                        DispatchQueue.main.async {
                            self.fetchedProcesses.append(contentsOf: built)
                        }
                        // Fetch next page if available
                        if let next = page.queryCursor {
                            handlePage(query, cursor: next)
                        }
                    }
                }
            } else {
                publicDB.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
                    switch result {
                    case .failure(let error):
                        print("CloudKit fetch error: \(error)")
                    case .success(let page):
                        let records = page.matchResults.compactMap { _, result in
                            try? result.get()
                        }
                        let built = records.compactMap { DevProcess(record: $0) }
                        DispatchQueue.main.async {
                            self.fetchedProcesses = built
                        }
                        // Fetch next page if available
                        if let next = page.queryCursor {
                            handlePage(query, cursor: next)
                        }
                    }
                }
            }
        }
        handlePage(query, cursor: nil)
    }
}

@MainActor
struct DownloadCard : View {
    @Environment(\.modelContext) private var modelContext
    @State var reportSheetIsPresented: Bool = false
    let process: DevProcess
    var downloaded: Bool
    var body: some View {
            GroupBox {
                VStack {
                    HStack {
                        Text(process.nickname)
                            .font(.title)
                            .fontWeight(.bold)
                        Spacer()
                        Text(process.sortedSteps.count.description + " steps")
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
                                .tint(.green)
                        }
                        
                        Button {
                            modelContext.insert(process)
                            try? modelContext.save()
                        } label: {
                            Image(systemName: downloaded ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .tint(.blue)
                        }
                        .disabled(downloaded)
                        .padding(.horizontal, 10)
                        Spacer()
                        Button{
                            reportSheetIsPresented = true
                        } label: {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                                .tint(.red)
                        }
                        .sheet(isPresented: $reportSheetIsPresented) {
                            VStack {
                                Text("Report Sheet")
                            }
                        }
                        
                    }
                }
            }
            
    }
    
   
    
}

struct UploadSheet : View {
    let publicDB = CKContainer(identifier: "iCloud.icloud.JackKroll.LabAssistant").publicCloudDatabase
    @Environment(\.dismiss) var dismiss
    @State private var uploadStatus: String? = nil
    @Query private var ownProcesses: [DevProcess]
    @AppStorage("appEULAAgree") var agreeToEULA: Bool = false
    var body: some View {
        VStack{
            if ownProcesses.isEmpty {
                ContentUnavailableView("You haven't created any presets yet!", systemImage: "xmark")
            }
            ScrollView {
                GroupBox("How does this work?") {
                    Text("By optionally uploading your processeses, you can share them with others. It will upload a copy that cannot be updated by you or others. They will not be immedietly visible due to an approval process.")
                }
                .padding()
                if !agreeToEULA {
                    GroupBox("Upload Agreement") {
                        Text("I understand that my content is subject to approval. The content I submit will not contain objectionable content and may be subject to removal from the public repository following additional review even if conditionally approved.")
                        Toggle(isOn: $agreeToEULA) {
                            Text("I agree")
                        }
                        .disabled(agreeToEULA)
                        
                    }
                    .padding()
                }
                ForEach(ownProcesses) { process in
                    GroupBox(process.nickname){
                        Button{
                            Task {
                                await upload(process: process)
                            }
                        } label: {
                            Text("Upload to Public Repository")
                        }
                        .disabled(!agreeToEULA)
                        .buttonSizing(.flexible)
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                    .padding()
                    
                    
                }
                if let uploadStatus {
                    Text(uploadStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                Spacer()
            }
        }
        .onDisappear {
            uploadStatus = nil
        }
        .navigationTitle("Upload Presets")
        .toolbar {
            ToolbarItem {
                Button(role: .close) {
                    dismiss()
                }
            }
        }
    }
    
    private func makeRecord(from process: DevProcess) async -> CKRecord {
        let record = CKRecord(recordType: "DevProcess")
        record["isApproved"] = false as CKRecordValue
        record["nickname"] = process.nickname as CKRecordValue
        record["notes"] = process.notes as CKRecordValue
        record["uploadUser"] = try? await CKContainer.default().userRecordID().recordName as CKRecordValue
        let stepsArray: [SingleStep] = process.steps ?? []
        if let data = try? JSONEncoder().encode(stepsArray) {
            record["stepsData"] = data as CKRecordValue
        }
        return record
    }

    
    private func upload(process: DevProcess) async {
        let record = await makeRecord(from: process)
        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
                publicDB.save(record) { saved, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let saved = saved {
                        continuation.resume(returning: saved)
                    } else {
                        continuation.resume(throwing: NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown CloudKit save result"]))
                    }
                }
            }
            await MainActor.run { uploadStatus = "Uploaded \(process.nickname)" }
        } catch {
            print("CloudKit upload error: \(error)")
            await MainActor.run { uploadStatus = "Failed to upload: \(error.localizedDescription)" }
        }
    }
}


#Preview {
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
    
    return PresetView()
        .modelContainer(container)
}

