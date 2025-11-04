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
    var expiryDate: Date?
    var max: Double
    var current: Double
    var notes: String?
    var tags : [Tag] = []
    var units: Units
    
    init(nickname: String, expiryDate: Date? = nil, max: Double, current: Double, notes: String? = nil, tags: [Tag] = [], units: Units = .ml) {
        self.nickname = nickname
        self.expiryDate = expiryDate
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

@Model
final class Tag : Identifiable, Equatable {
    var title: String
    var storedColor: String
    
    init(title: String, storedColor: String) {
        self.title = title
        self.storedColor = storedColor
    }
    
    init(title: String, storedColor: Color, environment: EnvironmentValues) {
        self.title = title
        self.storedColor = colorToHex(resolvedColor: storedColor.resolve(in: environment))
    }
    init(title: String) {
        self.title = title
        self.storedColor = colorToHex(resolvedColor: Color.Resolved(red: 84/255, green: 170/255, blue: 255/255))
    }
    
    func swiftColor() -> Color {
        hexToColor(hex: storedColor)
    }

    static func == (lhs: Tag, rhs: Tag) -> Bool {
        lhs.title == rhs.title
    }
}

func hexToColor (hex:String) -> Color {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
    
    var rgb: UInt64 = 0
    
    var r: CGFloat = 0.0
    var g: CGFloat = 0.0
    var b: CGFloat = 0.0
    var a: CGFloat = 1.0
    
    let length = hexSanitized.count
    
    Scanner(string: hexSanitized).scanHexInt64(&rgb)
    
    if length == 6 {
        r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        b = CGFloat(rgb & 0x0000FF) / 255.0
    }
    else if length == 8 {
        r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
        g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
        b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
        a = CGFloat(rgb & 0x000000FF) / 255.0
    }
    return Color(red: r, green: g, blue: b, opacity: a)
}

func colorToHex (resolvedColor:Color.Resolved, encodeAlpha: Bool = false) -> String {
    let r = resolvedColor.red
    let g = resolvedColor.green
    let b = resolvedColor.blue
    let a = resolvedColor.opacity
    
    if encodeAlpha {
        return String(format: "%02lX%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255),
                      lroundf(a * 255))
    }
    else {
        return String(format: "%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
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
