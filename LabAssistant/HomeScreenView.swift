//
//  HomeScreenView.swift
//  LabAssistant
//
//  Created by Jack Kroll on 10/26/25.
//

import SwiftUI
import SwiftData

struct HomeScreenView: View {
    
    var body: some View {
        TabView {
            Tab("Chemicals", systemImage: "testtube.2"){
                ChemicalStorageView()
            }
            Tab("Darkroom", systemImage: "film"){
                ProcessView()
            }
            Tab("Preset", systemImage: "square.and.arrow.down") {
                PresetView()
            }
        }
    }
}

#Preview {
    HomeScreenView()
}
