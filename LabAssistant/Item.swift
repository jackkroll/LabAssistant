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
    
    init(nickname: String, expriryDate: Date? = nil, max: Double, current: Double, notes: String? = nil) {
        self.nickname = nickname
        self.expriryDate = expriryDate
        self.max = max
        self.current = current
        self.notes = notes
        self.units = .ml
    }
    
    enum Units: String, Codable, CaseIterable {
        case ml, g
    }
    
}

final class Tag : Identifiable, Codable {
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
