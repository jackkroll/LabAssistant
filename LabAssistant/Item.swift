//
//  Item.swift
//  LabAssistant
//
//  Created by Jack Kroll on 9/28/25.
//

import Foundation
import SwiftData
import SwiftUI
import CloudKit

@Model
final class Chemical {
    var nickname: String = "Untitled"
    var expiryDate: Date?
    var max: Double = 500
    var current: Double = 500
    var notes: String?
    @Relationship(deleteRule: .nullify) var tags : [Tag]? = []
    @Relationship(deleteRule: .nullify) var associatedSteps: [SingleStep]?
    var units: Units = Units.ml
    
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
    var title: String = "Untitled"
    @Relationship(inverse: \Chemical.tags) var associatedChemicals: [Chemical]?
    var storedColor: String = colorToHex(resolvedColor: Color.Resolved(red: 84/255, green: 170/255, blue: 255/255))
    
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
final class DevProcess : Equatable {
    var nickname : String = "Untitled"
    var notes: String = ""
    @Relationship(deleteRule: .cascade, inverse: \SingleStep.associatedProcess) var steps: [SingleStep]? = []
    //@Relationship(deleteRule: .noAction, inverse: \DownloadableProcess.devProcess) var downloadableProcess: DownloadableProcess? = nil
    var sortedSteps : [SingleStep] {
        get {
            if steps == nil {
                return []
            }
            return steps!.sorted(by: {$0.index < $1.index})
        }
        set {
            steps = newValue
        }
    }
    
    var estTime: TimeInterval? {
        var time : TimeInterval? = nil
        for step in sortedSteps {
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
    
    convenience init(nickname: String, notes: String, steps: [SingleStep]?) {
        self.init(nickname: nickname, notes: notes, steps: steps ?? [])
    }

    convenience init?(record: CKRecord) {
        record["isApproved"] = nil
        record["uploadUser"] = nil
        let nickname = record["nickname"] as? String ?? "Untitled"
        let notes = record["notes"] as? String ?? ""
        
        
        var builtSteps: [SingleStep] = []
        let stepData: Data? = record["stepsData"] as? Data
        if stepData != nil {
            do {
                struct StepDTO: Codable { let title: String; let index: Int; let notes: String?; let autoAdvance: Bool?; let totalDuration: Double?; let substepTitle: String?; let substepDuration: Double?; let substepGap: Double? }
                let decoded = try JSONDecoder().decode([StepDTO].self, from: stepData!)
                builtSteps = decoded.map { dto in
                    let sub: SubstepProcess? = {
                        if let st = dto.substepTitle, let d = dto.substepDuration, let g = dto.substepGap {
                            return SubstepProcess(title: st, duration: d, gap: g)
                        }
                        return nil
                    }()
                    return SingleStep(
                        title: dto.title,
                        index: dto.index,
                        notes: dto.notes ?? "",
                        autoAdvance: dto.autoAdvance ?? true,
                        associatedChemicals: [],
                        totalDuration: dto.totalDuration,
                        substep: sub
                    )
                }
            } catch {
                // If steps JSON is malformed, fall back to empty steps
                print("malformed")
                builtSteps = []
            }
        }

        self.init(nickname: nickname, notes: notes, steps: builtSteps)
        // `downloadableProcess` will remain nil unless explicitly set later
    }
}

@Model
final class SingleStep: Identifiable, Codable {
    var id : UUID = UUID()
    var index: Int = 0
    var title: String = "Untitled"
    var notes: String = ""
    var autoAdvance: Bool = true
    @Relationship(deleteRule: .nullify, inverse: \Chemical.associatedSteps) var associatedChemicals: [Chemical]? = []
    @Relationship(deleteRule: .nullify) var associatedProcess: DevProcess?

    var totalDuration: TimeInterval?
    @Relationship(deleteRule: .cascade) var substep: SubstepProcess?

    private enum CodingKeys: String, CodingKey { case id, index, title, notes, autoAdvance, totalDuration, substep }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.index = try c.decode(Int.self, forKey: .index)
        self.title = try c.decode(String.self, forKey: .title)
        self.notes = try c.decode(String.self, forKey: .notes)
        self.autoAdvance = try c.decode(Bool.self, forKey: .autoAdvance)
        self.associatedChemicals = []
        self.associatedProcess = nil
        self.totalDuration = try c.decodeIfPresent(TimeInterval.self, forKey: .totalDuration)
        self.substep = try c.decodeIfPresent(SubstepProcess.self, forKey: .substep)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(index, forKey: .index)
        try c.encode(title, forKey: .title)
        try c.encode(notes, forKey: .notes)
        try c.encode(autoAdvance, forKey: .autoAdvance)
        try c.encodeIfPresent(totalDuration, forKey: .totalDuration)
        try c.encodeIfPresent(substep, forKey: .substep)
    }
    
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
    
    convenience init(title: String, index: Int) {
        self.init(title: title, index: index, notes: "", autoAdvance: true, associatedChemicals: [], totalDuration: nil, substep: nil)
    }
}

@Model
final class SubstepProcess: Codable {
    @Relationship(deleteRule: .nullify, inverse: \SingleStep.substep) var associatedStep: SingleStep?
    var title: String = "Untitled"
    var duration: TimeInterval = 30
    var gap: TimeInterval = 30

    private enum CodingKeys: String, CodingKey { case title, duration, gap }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.associatedStep = nil
        self.title = try c.decode(String.self, forKey: .title)
        self.duration = try c.decode(TimeInterval.self, forKey: .duration)
        self.gap = try c.decode(TimeInterval.self, forKey: .gap)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(duration, forKey: .duration)
        try c.encode(gap, forKey: .gap)
    }
    
    init(title: String, duration: TimeInterval, gap: TimeInterval) {
        self.title = title
        self.duration = duration
        self.gap = gap
    }
}

@Model
final class DownloadableProcess: Identifiable {
    var id: UUID = UUID()
    var approved: Bool = false
    var userSubmissionID: String
    @Relationship(deleteRule: .nullify) var devProcess: DevProcess
    
    init(id: UUID, userSubmissionID: String, devProcess: DevProcess) {
        self.id = id
        self.approved = false
        self.userSubmissionID = userSubmissionID
        self.devProcess = devProcess
    }
}

