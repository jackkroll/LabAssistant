//
//  TagEditorView.swift
//  LabAssistant
//
//  Created by Jack Kroll on 11/2/25.
//

import SwiftUI
import SwiftData

struct TagEditorView: View {
    @Environment(\.self) var environment
    @Environment(\.modelContext) private var modelContext
    @Query private var allTags: [Tag]
    @State var selectedColor: Color = .blue
    @Binding var appliedTags : [Tag]?
    @State var newTagTitle: String = ""
    
    @State var selectedTag : Tag? = nil
    @State var tagModifySheetIsPresented: Bool = false
    var body: some View {
        if appliedTags == nil {
            ProgressView()
        }
        else {
            VStack {
                Form {
                    Section {
                        ScrollView(.horizontal){
                            HStack {
                                if appliedTags!.isEmpty {
                                    Text("No tags applied")
                                        .foregroundStyle(.secondary)
                                }
                                ForEach(appliedTags!) { tag in
                                    TagRender(tag: tag)
                                        .onTapGesture {
                                            withAnimation {
                                                appliedTags!.removeAll { $0.id == tag.id }
                                            }
                                        }
                                        .onLongPressGesture {
                                            selectedTag = tag
                                        }
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .clipShape(Capsule())
                    } header: {
                        Text("Applied Tags")
                    } footer: {
                        Text("**Long press** a tag to modify it")
                    }
                    
                    Section {
                        ScrollView(.horizontal){
                            HStack {
                                ForEach(allTags) { tag in
                                    if !appliedTags!.contains(tag) {
                                        TagRender(tag: tag)
                                            .onTapGesture {
                                                withAnimation {
                                                    if !appliedTags!.contains(where: { $0.id == tag.id }) {
                                                        appliedTags!.append(tag)
                                                    }
                                                }
                                            }
                                            .onLongPressGesture {
                                                selectedTag = tag
                                            }
                                    }
                                    
                                }
                            }
                            if allTags.isEmpty || allTags.allSatisfy({appliedTags!.contains($0)}) {
                                Text("No more tags available! Make some more!")
                                    .foregroundStyle(.secondary)
                                
                            }
                        }
                        .scrollIndicators(.hidden)
                        .clipShape(Capsule())
                    } header: {
                        Text("Available Tags")
                    } footer: {
                        Text("**Tap** a tag to apply it")
                    }
                    
                    Section {
                        TextField("Tag Title", text: $newTagTitle)
                        ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
                        Button("Create Tag") {
                            let newTag = Tag(title: newTagTitle, storedColor: selectedColor, environment: environment)
                            withAnimation {
                                modelContext.insert(newTag)
                            }
                            try? modelContext.save()
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonSizing(.flexible)
                        .fontWeight(.semibold)
                    } header: {
                        Text("Create a New Tag")
                    }
                }
                .sheet(isPresented: $tagModifySheetIsPresented) {
                    if selectedTag != nil {
                        IndividualTagEditor(tag: selectedTag!)
                            .presentationDetents([.medium])
                    }
                    else {
                        ProgressView()
                    }
                }
                .onChange(of: selectedTag) { _, new in
                    if new != nil {
                        tagModifySheetIsPresented = true
                    }
                }
                .onChange(of: tagModifySheetIsPresented) { _, new in
                    if new == false {
                        selectedTag = nil
                    }
                }
                .onChange(of: allTags) { old, new in
                    if old.count >= new.count {
                        for tag in appliedTags! {
                            if !allTags.contains(tag) {
                                withAnimation {
                                    appliedTags!.removeAll(where: { $0.id == tag.id })
                                }
                            }
                        }
                    }
                    
                }
            }
        }
    }
}

struct IndividualTagEditor : View {
    @Environment(\.self) var environment
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @State var tag : Tag
    @State var newTitle: String = ""
    @State var newTagColor: Color = .blue
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    HStack {
                        Text("Title: ")
                        TextField(tag.title, text: $newTitle)
                    }
                    ColorPicker("Color", selection: $newTagColor, supportsOpacity: false)
                    Button("Delete Tag", role: .destructive){
                        withAnimation {
                            modelContext.delete(tag)
                            try? modelContext.save()
                        }
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonSizing(.flexible)
                    .fontWeight(.semibold)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction){
                    Button(role: .close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction){
                    Button(role: .confirm) {
                        // New title is real, update
                        if !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            tag.title = newTitle
                        }
                        tag.storedColor = colorToHex(resolvedColor: newTagColor.resolve(in: environment))
                        dismiss()
                    }
                }
            }
            .navigationTitle(tag.title)
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                try? modelContext.save()
            }
        }
    }
}

/*
#Preview {
    @ViewBuilder
    @Previewable @State var appliedTags = [Tag(title: "Tag A"), Tag(title: "Tag B")]
    @Previewable @State var tags: [Tag] = [Tag(title: "Tag A"), Tag(title: "Tag B")]
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Tag.self, configurations: config)
        let context = container.mainContext
        // Seed a few example chemicals for the mixture picker
        let tag1 = Tag(title: "Stored Tag A")
        let tag2 = Tag(title: "Stored Tag B")
        let tag3 = Tag(title: "Stored Tag C")
        let tag4 = Tag(title: "Stored Tag D")
        context.insert(tag1)
        context.insert(tag2)
        context.insert(tag3)
        context.insert(tag4)
        try context.save()
        @ViewBuilder var view: some View { TagEditorView(appliedTags: $appliedTags)
                .modelContainer(container)
        }
    }
    catch {
        @ViewBuilder var view: some View {
        return TagEditorView(appliedTags: $tags)
            
    }
}*/
