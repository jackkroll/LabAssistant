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
    @Binding var selectedComponantAmount: Double?
    
    @State var partA: Double? = nil
    @State var partB: Double? = nil
    
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
                
                
                Section(header: Text("Component Breakdown")) {
                    HStack {
                        Text("Part A: \(String(format: "%.3f", partA ?? 0))")
                            .contentTransition(.numericText())
                        Spacer()
                        Button("Add to mixture"){
                            selectedComponantAmount = partA
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isValid())
                        
                    }
                    HStack {
                        Text("Part B: \(String(format: "%.3f", partB ?? 0))")
                            .contentTransition(.numericText())
                        Spacer()
                        Button("Add to mixture"){
                            selectedComponantAmount = partB
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isValid())
                    }
                }
                .onChange(of: workingVolume + ratioX) {
                    if let total = Double(workingVolume),
                       let x = Double(ratioX),
                       x > 0 {
                        withAnimation{
                            partA = total / (x + 1)
                            partB = partA! * x
                        }
                    }
                    else {
                        withAnimation{
                            partA = 0
                            partB = 0
                        }
                    }
                }
                
                
            }
        }
    }
    
    func isValid() -> Bool {
        return (Double(workingVolume) != nil) && (Double(ratioX) != nil) && (Double(ratioX)! > 0)
    }
}

#Preview {
    RatioCalc(selectedComponantAmount: .constant(nil))
}
