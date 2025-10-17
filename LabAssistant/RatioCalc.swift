//
//  RatioCalc.swift
//  LabAssistant
//
//  Created by Jack Kroll on 10/16/25.
//

import SwiftUI

struct RatioCalc: View {
    @State private var workingVolume: String = ""
    @State private var ratioX: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Total Working Solution Volume")) {
                    TextField("Total volume (e.g. 100)", text: $workingVolume)
                        .keyboardType(.decimalPad)
                }
                Section(header: Text("Ratio")) {
                    HStack {
                        Text("1:")
                            .bold()
                        TextField("X", text: $ratioX)
                            .keyboardType(.decimalPad)
                    }
                }
                if let total = Double(workingVolume),
                   let x = Double(ratioX),
                   x > 0 {
                    let partA = total / (x + 1)
                    let partB = partA * x
                    Section(header: Text("Component Breakdown")) {
                        Text("Part A: \(String(format: "%.2f", partA))")
                        Text("Part B: \(String(format: "%.2f", partB))")
                    }
                    
                }
            }
            .navigationTitle("Ratio Calculator")
        }
    }
}

#Preview {
    RatioCalc()
}
