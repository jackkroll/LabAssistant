//
//  Item.swift
//  LabAssistant
//
//  Created by Jack Kroll on 9/28/25.
//

import Foundation
import SwiftData
import SwiftUI

enum NamedColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown, gray, black, white, clear

    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .mint
        case .teal: return .teal
        case .cyan: return .cyan
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .brown: return .brown
        case .gray: return .gray
        case .black: return .black
        case .white: return .white
        case .clear: return .clear
        }
    }
}

@Model
final class Chemical {
    var nickname: String
    var expriryDate: Date?
    var max: Double
    var current: Double
    var notes: String?
    var tags : [Tag] = []
    var units: Units
    
    init(nickname: String, expriryDate: Date? = nil, max: Double, current: Double, notes: String? = nil, tags: [Tag] = [], units: Units = .ml) {
        self.nickname = nickname
        self.expriryDate = expriryDate
        self.max = max
        self.current = current
        self.notes = notes
        self.tags = tags
        self.units = units
    }
    
    enum Units: String, Codable, CaseIterable {
        case ml, g
    }
    
}

final class Tag : Identifiable, Codable, Equatable {
    var title: String
    var storedColor: NamedColor
    
    init(title: String) {
        self.title = title
        self.storedColor = .blue
    }
    
    func swiftColor() -> Color {
        storedColor.color
    }

    static func == (lhs: Tag, rhs: Tag) -> Bool {
        lhs.title == rhs.title
    }
}

@Model
final class DevProcess {
    var nickname : String
    var notes: String
    var steps: [SingleStep]
    var sortedSteps : [SingleStep] {
        get {
            return steps.sorted(by: {$0.index < $1.index})
        }
        set {
            steps = newValue
        }
    }
    
    var estTime: TimeInterval? {
        var time : TimeInterval? = nil
        for step in steps {
            if step.totalDuration != nil {
                if time == nil {
                    time = 0
                }
                time! += step.totalDuration!
            }
        }
        return time
    }
    
    init(nickname: String, notes: String = "", steps: [SingleStep]) {
        self.nickname = nickname
        self.notes = notes
        self.steps = steps
    }
    
}

@Model
final class SingleStep: Identifiable {
    var id : UUID
    var index: Int
    var title: String
    var notes: String
    var autoAdvance: Bool
    var associatedChemicals: [Chemical]

    var totalDuration: TimeInterval?
    var substep: SubstepProcess?
    
    init(title: String, index: Int,notes: String = "", autoAdvance: Bool, associatedChemicals: [Chemical], totalDuration: TimeInterval? = nil, substep: SubstepProcess? = nil) {
        self.id = UUID()
        self.title = title
        self.index = index
        self.notes = notes
        self.autoAdvance = autoAdvance
        self.associatedChemicals = associatedChemicals
        self.totalDuration = totalDuration
        self.substep = substep
    }
}

@Model
final class SubstepProcess {
    var title: String
    var duration: TimeInterval
    var gap: TimeInterval
    
    init(title: String, duration: TimeInterval, gap: TimeInterval) {
        self.title = title
        self.duration = duration
        self.gap = gap
    }
}
