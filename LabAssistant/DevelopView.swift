//
//  DevelopView.swift
//  LabAssistant
//
//  Created by Jack Kroll on 10/25/25.
//

import SwiftUI
import Combine

struct DevelopView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State var selectedTab: Int = 0
    @State var timeRemaining : TimeInterval?
    
    @State var subprocessTimeRemaining : TimeInterval?
    @State var subprocessBufferRemaining : TimeInterval?
    
    @State var displaySubprocess : Bool? = nil
    @State var timer : Timer? = nil
    
    @State var isPaused : Bool = false

    var process : DevProcess
    var body: some View {
        TabView(selection: $selectedTab){
            ForEach(process.sortedSteps) { step in
                VStack {
                    VStack {
                        Text(step.title)
                            .fontWeight(.bold)
                            .font(.largeTitle)
                        Text(step.notes)
                            .fontWeight(.semibold)
                            .font(.title2)
                    }
                    
                    if timeRemaining != nil  || subprocessTimeRemaining != nil {
                        OrientationAdaptiveStack {
                            if timeRemaining != nil {
                                Text(formatSecondsToMinutesSeconds(Int(timeRemaining!)))
                                    .contentTransition(.numericText(countsDown: true))
                                    .font(.system(size: 100, weight: .black, design: .monospaced))
                                    .minimumScaleFactor(0.01)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    
                            }
                           
                            if step.substep != nil && subprocessTimeRemaining != nil && subprocessBufferRemaining != nil {
                                //Spacer()
                                GroupBox{
                                    VStack {
                                        Text(step.substep!.title)
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                        if subprocessTimeRemaining != nil && subprocessTimeRemaining! > 0 {
                                            HStack {
                                                Text(formatSecondsToMinutesSeconds(Int(subprocessTimeRemaining!)))
                                                    .contentTransition(.numericText(countsDown: true))
                                                    .font(.system(size: 50, weight: .bold, design: .monospaced))
                                                    .padding()
                                            }
                                        }
                                        else if subprocessBufferRemaining != nil && subprocessBufferRemaining! > 0 {
                                            Text(formatSecondsToMinutesSeconds(Int(subprocessBufferRemaining!)))
                                                .contentTransition(.numericText(countsDown: true))
                                                .font(.system(size: 50, weight: .bold, design: .default))
                                                .padding()
                                        }
                                    }
                                    .foregroundStyle(subprocessTimeRemaining! > 0 ? .green : .gray)
                                    .frame(maxWidth:.infinity)
                                }
                                
                            }
                            //Spacer()
                        }
                    }
            
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Button {
                            withAnimation {
                                selectedTab -= 1
                            }
                        } label: {
                            Image(systemName: "arrow.left.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 75, height: 75)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .disabled(step.index == 0)
                        
                        Spacer()
                        
                        if step.totalDuration != nil || step.substep?.duration != nil {
                            Button {
                                if isPaused {
                                    generateNewTimer(newStep: step)
                                }
                                else {
                                    timer?.invalidate()
                                }
                                isPaused.toggle()
                            } label: {
                                Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 75, height: 75)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }
                        
                        
                        Spacer()
                        
                        Button {
                            withAnimation {
                                selectedTab += 1
                            }
                        } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 75, height: 75)
                        }
                        .disabled(selectedTab == process.sortedSteps.count - 1)
                    }
                    .padding()
                }
                .tag(step.index)
                
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedTab) {
            timer?.invalidate()
            isPaused = false
            let newStep = process.sortedSteps[selectedTab]
            
            timeRemaining = newStep.totalDuration
            subprocessTimeRemaining = newStep.substep?.duration
            subprocessBufferRemaining = subprocessTimeRemaining != nil ? 0 : nil
            
            if timeRemaining != nil || subprocessTimeRemaining != nil {
                generateNewTimer(newStep: newStep)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }

    
    func generateNewTimer(newStep: SingleStep) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            withAnimation {
                timerAction(newStep: newStep)
            }
    }
    
        func timerAction(newStep: SingleStep) {
            if timeRemaining != nil {
                timeRemaining! -= 1
                if timeRemaining! <= 0 && newStep.autoAdvance{
                    withAnimation {
                        selectedTab += 1
                    }
                }
            }
            if subprocessTimeRemaining != nil && subprocessBufferRemaining != nil && subprocessBufferRemaining! <= 0{
                if subprocessTimeRemaining! > 0 {
                    subprocessTimeRemaining! -= 1
                }
                if subprocessTimeRemaining! <= 0 {
                    subprocessBufferRemaining! = newStep.substep!.gap
                }
            }
            else if subprocessBufferRemaining != nil {
                if subprocessBufferRemaining! > 0 {
                    subprocessBufferRemaining! -= 1
                }
                if subprocessBufferRemaining! <= 0 {
                    subprocessTimeRemaining! = newStep.substep!.duration
                }
            }
        }

    }
    func formatSecondsToMinutesSeconds(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02i:%02i", minutes, seconds)
    }
}

#Preview("Ilford B&W") {
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
    DevelopView(process: ilfordBW)
}
