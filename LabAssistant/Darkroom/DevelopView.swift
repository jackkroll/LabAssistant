//
//  DevelopView.swift
//  LabAssistant
//
//  Created by Jack Kroll on 10/25/25.
//

import SwiftUI
import Combine

private struct PresetsSheetContext: Identifiable {
    let step: SingleStep

    var id: UUID {
        step.id
    }
}

struct DevelopView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dismiss) var dismiss
    @State var selectedTab: Int = 0
    @State var timeRemaining : TimeInterval?
    
    @State var subprocessTimeRemaining : TimeInterval?
    @State var subprocessBufferRemaining : TimeInterval?
    
    @State var displaySubprocess : Bool? = nil
    @State var timer : Timer? = nil
    
    @State var isPaused : Bool = false
    @State private var presetsSheetContext: PresetsSheetContext? = nil
    @State private var lastTabForDurationChange: Int = -1
    
    var currentStep : SingleStep? {
        let steps = process.sortedSteps
        guard !steps.isEmpty else { return nil }
        return steps[clampedSelectedTab(for: steps)]
    }

    var process : DevProcess
    var body: some View {
        TabView(selection: $selectedTab){
            if process.steps?.isEmpty ?? true {
                    VStack {
                        ContentUnavailableView("No Steps Added", systemImage: "list.clipboard")
                    }
            }
            ForEach(Array(process.sortedSteps.enumerated()), id: \.element.id) { offset, step in
                VStack {
                    VStack {
                        OrientationAdaptiveStack {
                            Text(step.title)
                                .fontWeight(.bold)
                                .font(.largeTitle)
                                .minimumScaleFactor(0.5)
                                .layoutPriority(0.5)
                        }
                        if step.associatedChemicals != nil && step.associatedChemicals!.count > 0 {
                            HStack {
                                ForEach(step.associatedChemicals!) { chemical in
                                    TagRender(tag: Tag(title: chemical.nickname))
                                }
                            }
                        }
                        Text(step.notes)
                            .fontWeight(.semibold)
                            .font(.title3)
                            .minimumScaleFactor(0.5)
                        
                    }
                    .ignoresSafeArea(.all)
                    
                    if timeRemaining != nil  || subprocessTimeRemaining != nil {
                        OrientationAdaptiveStack {
                            if let timeRemaining = timeRemaining {
                                    Text(timeRemaining.formatToMinSec())
                                        .contentTransition(.numericText(countsDown: true))
                                        .font(.system(size: 100, weight: .black, design: .monospaced))
                                        .minimumScaleFactor(0.5)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .foregroundStyle(timeRemaining < 0 ? .red : .primary)
                                        .frame(maxHeight: 150)
                                        .onLongPressGesture {
                                            withAnimation {
                                                presetsSheetContext = PresetsSheetContext(step: step)
                                            }
                                        }
                                        .layoutPriority(1)
                            }
                           
                            if step.substep != nil && subprocessTimeRemaining != nil && subprocessBufferRemaining != nil {
                                //Spacer()
                                GroupBox{
                                    VStack {
                                        if subprocessTimeRemaining! > 0 {
                                            Image(systemName: "stopwatch.fill")
                                                .symbolRenderingMode(.multicolor)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(minWidth: 25, maxWidth: 50)
                                            
                                        }
                                        Text(step.substep!.title)
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                        if subprocessTimeRemaining != nil && subprocessTimeRemaining! > 0 {
                                            HStack {
                                                Text(subprocessTimeRemaining!.formatToMinSec())
                                                    .contentTransition(.numericText(countsDown: true))
                                                    .font(.system(size: 50, weight: .bold, design: .monospaced))
                                                    .minimumScaleFactor(0.5)
                                                    .layoutPriority(1)
                                            }
                                        }
                                        else if subprocessBufferRemaining != nil && subprocessBufferRemaining! > 0 {
                                            Text(subprocessBufferRemaining!.formatToMinSec())
                                                .contentTransition(.numericText(countsDown: true))
                                                .font(.system(size: 50, weight: .bold, design: .default))
                                                .minimumScaleFactor(0.5)
                                                .layoutPriority(1)
                                            
                                        }
                                    }
                                    .foregroundStyle(subprocessTimeRemaining! > 0 ? .green : .gray)
                                    .frame(minWidth: 200, maxWidth: 500)
                                    .layoutPriority(1)
                                }
                                
                            }
                            //Spacer()
                        }
                    }
                }
                
                .tag(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
           loadPage()
        }
        .onChange(of: selectedTab) {
            loadPage()
        }
        .onChange(of: currentStep?.totalDuration) { oldValue, newValue in
            guard let newTotal = newValue else { return }
            if lastTabForDurationChange == selectedTab {
                if let oldTotal = oldValue, let remaining = timeRemaining {
                    let elapsed = oldTotal - remaining
                    timeRemaining = newTotal - elapsed
                } else {
                    timeRemaining = newTotal
                }
            } else {
                timeRemaining = newTotal
            }
            lastTabForDurationChange = selectedTab
        }
    }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .overlay(alignment: .topTrailing) {
            let steps = process.sortedSteps
            if !steps.isEmpty {
                let selectedIndex = clampedSelectedTab(for: steps)
                let step = steps[selectedIndex]
                if let presets = step.tempDuration?.count, presets > 0 {
                    Button {
                        withAnimation {
                            presetsSheetContext = PresetsSheetContext(step: step)
                        }
                    } label: {
                        Image(systemName: "list.bullet.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 75, height: 75)
                    }
                    .padding()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            let steps = process.sortedSteps
            if !steps.isEmpty {
                let selectedIndex = clampedSelectedTab(for: steps)
                let step = steps[selectedIndex]
                HStack {
                    Button {
                        withAnimation {
                            if selectedIndex == 0 {
                                dismiss()
                            }
                            else {
                                selectedTab = selectedIndex - 1
                            }
                        }
                    } label: {
                        Image(systemName: selectedIndex == 0 ? "xmark.circle.fill" : "arrow.left.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 75, height: 75)
                    }
                    .accessibilityLabel(selectedIndex == 0 ? "end" : "previous" )
                    
                    Spacer()
                    
                    if step.totalDuration != nil || step.substep?.duration != nil {
                        Button {
                            withAnimation {
                                loadPage(unpause: !isPaused)
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 75, height: 75)
                        }
                        .animation(.easeInOut, value: isPaused)
                        .accessibilityLabel("restart")
                        
                        Button {
                            if isPaused {
                                generateNewTimer(newStep: step)
                            }
                            else {
                                timer?.invalidate()
                            }
                            withAnimation {
                                isPaused.toggle()
                            }
                        } label: {
                            Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 75, height: 75)
                        }
                        .accessibilityLabel(isPaused ? "play" : "pause")
                    }
                    
                    
                    Spacer()
                    
                    Button {
                        withAnimation {
                            if selectedIndex == steps.count - 1 {
                                dismiss()
                            }
                            else {
                                selectedTab = selectedIndex + 1
                            }
                        }
                    } label: {
                        Image(systemName: selectedIndex == steps.count - 1 ? "xmark.circle.fill" : "arrow.right.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 75, height: 75)
                    }
                    .accessibilityLabel(selectedIndex == steps.count - 1 ? "end" : "next")
                }
            }
        }
        .sheet(item: $presetsSheetContext) { ctx in
            NavigationStack {
                TempSelectionSheet(step: ctx.step)
                    .presentationDetents([.medium, .large])
            }
        }
	            
        }
	    
    private func clampedSelectedTab(for steps: [SingleStep]) -> Int {
        guard !steps.isEmpty else { return 0 }
        return min(max(selectedTab, 0), steps.count - 1)
    }
    
    func loadPage(unpause: Bool = true) {
        timer?.invalidate()
        isPaused = !unpause
        let steps = process.sortedSteps
        guard !steps.isEmpty else {
            timeRemaining = nil
            subprocessTimeRemaining = nil
            subprocessBufferRemaining = nil
            timer = nil
            return
        }
        let selectedIndex = clampedSelectedTab(for: steps)
        if selectedTab != selectedIndex {
            selectedTab = selectedIndex
        }
        let newStep = steps[selectedIndex]
        
        timeRemaining = newStep.totalDuration
        subprocessTimeRemaining = newStep.substep?.duration
        subprocessBufferRemaining = subprocessTimeRemaining != nil ? 0 : nil
        
        if timeRemaining != nil || subprocessTimeRemaining != nil {
            if unpause {
                generateNewTimer(newStep: newStep)
            }
        }
    }

    
    func generateNewTimer(newStep: SingleStep) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            guard currentStep?.id == newStep.id else {
                timer.invalidate()
                return
            }
            timerAction(newStep: newStep)
        }
    
        func timerAction(newStep: SingleStep) {
            if timeRemaining != nil {
                timeRemaining! -= 1
                if timeRemaining! <= 0 && newStep.autoAdvance{
                    withAnimation {
                        let steps = process.sortedSteps
                        let selectedIndex = clampedSelectedTab(for: steps)
                        if selectedIndex < steps.count - 1 {
                            selectedTab = selectedIndex + 1
                        }
                        else {
                            timer?.invalidate()
                            self.timer = nil
                            withAnimation {
                                isPaused = true
                            }
                        }
                    }
                }
            }
            guard let substep = newStep.substep else { return }

            if subprocessTimeRemaining != nil && subprocessBufferRemaining != nil && subprocessBufferRemaining! <= 0{
                if subprocessTimeRemaining! > 0 {
                    subprocessTimeRemaining! -= 1
                }
                if subprocessTimeRemaining! <= 0 {
                    subprocessBufferRemaining! = substep.gap
                }
            }
            else if subprocessBufferRemaining != nil {
                if subprocessBufferRemaining! > 0 {
                    subprocessBufferRemaining! -= 1
                }
                if subprocessBufferRemaining! <= 0 {
                    subprocessTimeRemaining! = substep.duration
                }
            }
        }

    }
}

extension TimeInterval {
    func formatToMinSec() -> String {
        let totalSeconds = Int(self)
        let minutes = abs((totalSeconds / 60) % 60)
        let seconds = abs(totalSeconds % 60)
        let isNegative = self < 0
        return String(format: "\(isNegative ? "-" : "")%02d:%02d", minutes, seconds)
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
            autoAdvance: false,
            associatedChemicals: [],
            totalDuration: 5,
            substep: agitation
        ),
        SingleStep(
            title: "Develop",
            index: 1,
            notes: "Total 9:00. Initial 30s agitation, then 10s each minute.",
            autoAdvance: false,
            associatedChemicals: [],
            totalDuration: 9 * 60,
            substep: agitation,
            tempDuration: [.init(temperature: 20, duration: 6*60)]
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
            totalDuration: 2,
            substep: nil
        )
    ]

    let ilfordBW = DevProcess(
        nickname: "HP5+ in DD-X",
        steps: steps
    )
    DevelopView(process: ilfordBW)
}

#Preview {
    let ilfordBW = DevProcess(
        nickname: "HP5+ in DD-X", steps: []
    )
    DevelopView(process: ilfordBW)
}
