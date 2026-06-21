//
//  PresetStepSerialization.swift
//  LabAssistant
//

import Foundation

struct PresetSubstepDTO: Codable, Equatable {
    let title: String
    let duration: TimeInterval
    let gap: TimeInterval

    init(title: String, duration: TimeInterval, gap: TimeInterval) {
        self.title = title
        self.duration = duration
        self.gap = gap
    }

    @MainActor
    init(substep: SubstepProcess) {
        self.title = substep.title
        self.duration = substep.duration
        self.gap = substep.gap
    }

    @MainActor
    func makeSubstepProcess() -> SubstepProcess {
        SubstepProcess(title: title, duration: duration, gap: gap)
    }
}

struct PresetTemperatureDurationDTO: Codable, Equatable {
    let temperature: Double?
    let unitsSymbol: String?
    let duration: TimeInterval

    init(temperature: Double?, unitsSymbol: String?, duration: TimeInterval) {
        self.temperature = temperature
        self.unitsSymbol = unitsSymbol
        self.duration = duration
    }

    @MainActor
    init(preset: TemperatureDuration) {
        self.temperature = preset.temperature
        self.unitsSymbol = preset.units.symbol
        self.duration = preset.duration
    }

    @MainActor
    func makeTemperatureDuration() -> TemperatureDuration {
        let units: UnitTemperature
        switch unitsSymbol {
        case UnitTemperature.fahrenheit.symbol:
            units = .fahrenheit
        case UnitTemperature.kelvin.symbol:
            units = .kelvin
        default:
            units = .celsius
        }
        return TemperatureDuration(temperature: temperature, units: units, duration: duration)
    }
}

struct PresetSingleStepDTO: Codable, Equatable {
    let id: UUID
    let index: Int
    let title: String
    let notes: String
    let autoAdvance: Bool
    let totalDuration: TimeInterval?
    let requestedTemperature: Double?
    let requestedTemperatureUnitsSymbol: String?
    let usesAutoTimeTiming: Bool
    let substep: PresetSubstepDTO?
    let tempDuration: [PresetTemperatureDurationDTO]?

    @MainActor
    init(step: SingleStep) {
        self.id = step.id
        self.index = step.index
        self.title = step.title
        self.notes = step.notes
        self.autoAdvance = step.autoAdvance
        self.totalDuration = step.totalDuration
        self.requestedTemperature = step.requestedTemperature
        self.requestedTemperatureUnitsSymbol = step.requestedTemperatureUnits.symbol
        self.usesAutoTimeTiming = step.usesAutoTimeTiming
        self.substep = step.substep.map { PresetSubstepDTO(substep: $0) }
        self.tempDuration = step.tempDuration?.map { PresetTemperatureDurationDTO(preset: $0) }
    }

    @MainActor
    func makeSingleStep() -> SingleStep {
        let units: UnitTemperature
        switch requestedTemperatureUnitsSymbol {
        case UnitTemperature.fahrenheit.symbol:
            units = .fahrenheit
        case UnitTemperature.kelvin.symbol:
            units = .kelvin
        default:
            units = .celsius
        }

        let step = SingleStep(
            title: title,
            index: index,
            notes: notes,
            autoAdvance: autoAdvance,
            associatedChemicals: [],
            totalDuration: totalDuration,
            requestedTemperature: requestedTemperature,
            requestedTemperatureUnits: units,
            usesAutoTimeTiming: usesAutoTimeTiming,
            substep: substep?.makeSubstepProcess(),
            tempDuration: tempDuration?.map { $0.makeTemperatureDuration() }
        )
        step.id = id
        return step
    }
}

private struct LegacyPresetStepDTO: Codable {
    let title: String
    let index: Int
    let notes: String?
    let autoAdvance: Bool?
    let totalDuration: Double?
    let substepTitle: String?
    let substepDuration: Double?
    let substepGap: Double?
}

@MainActor
enum PresetStepSerialization {
    static func encodeSteps(_ steps: [SingleStep]) throws -> Data {
        try JSONEncoder().encode(steps.map { PresetSingleStepDTO(step: $0) })
    }

    static func decodeSteps(from data: Data) -> [SingleStep] {
        if let dtos = try? JSONDecoder().decode([PresetSingleStepDTO].self, from: data) {
            return dtos.map { $0.makeSingleStep() }
        }

        if let legacy = try? JSONDecoder().decode([LegacyPresetStepDTO].self, from: data) {
            return legacy.map { dto in
                let substep: SubstepProcess? = {
                    if let title = dto.substepTitle,
                       let duration = dto.substepDuration,
                       let gap = dto.substepGap {
                        return SubstepProcess(title: title, duration: duration, gap: gap)
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
                    substep: substep
                )
            }
        }

        return []
    }
}
