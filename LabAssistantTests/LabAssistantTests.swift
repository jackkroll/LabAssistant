import XCTest
import SwiftUI
@testable import LabAssistant

@MainActor
final class LabAssistantTests: XCTestCase {
    func testColorHexRoundTripsThroughHelpers() {
        let resolved = Color.Resolved(red: 84 / 255, green: 170 / 255, blue: 255 / 255)

        let hex = colorToHex(resolvedColor: resolved)
        XCTAssertEqual(hex, "54AAFF")

        let roundTripped = hexToColor(hex: hex).resolve(in: EnvironmentValues())
        XCTAssertEqual(roundTripped.red, resolved.red, accuracy: 0.001)
        XCTAssertEqual(roundTripped.green, resolved.green, accuracy: 0.001)
        XCTAssertEqual(roundTripped.blue, resolved.blue, accuracy: 0.001)
        XCTAssertEqual(roundTripped.opacity, resolved.opacity, accuracy: 0.001)
    }

    func testDevProcessEstimatedTimeUsesSortedStepDurations() {
        let lateStep = SingleStep(
            title: "Finish",
            index: 1,
            notes: "",
            autoAdvance: true,
            associatedChemicals: [],
            totalDuration: 45
        )
        let earlyStep = SingleStep(
            title: "Start",
            index: 0,
            notes: "",
            autoAdvance: true,
            associatedChemicals: [],
            totalDuration: 75
        )

        let process = DevProcess(nickname: "Demo", notes: "", steps: [lateStep, earlyStep])

        XCTAssertEqual(process.sortedSteps.map(\.title), ["Start", "Finish"])
        XCTAssertEqual(process.estTime, 120)
    }

    func testSingleStepCodablePreservesNestedTimingData() throws {
        let substep = SubstepProcess(title: "Agitation", duration: 15, gap: 45)
        let preset = TemperatureDuration(temperature: 20, units: .celsius, duration: 540)
        let original = SingleStep(
            title: "Develop",
            index: 2,
            notes: "Watch carefully",
            autoAdvance: false,
            associatedChemicals: [],
            totalDuration: 540,
            requestedTemperature: 68,
            requestedTemperatureUnits: .fahrenheit,
            usesAutoTimeTiming: true,
            substep: substep,
            tempDuration: [preset]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SingleStep.self, from: data)

        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.index, original.index)
        XCTAssertEqual(decoded.requestedTemperature, original.requestedTemperature)
        XCTAssertEqual(decoded.requestedTemperatureUnits, .fahrenheit)
        XCTAssertTrue(decoded.usesAutoTimeTiming)
        XCTAssertEqual(decoded.substep?.title, "Agitation")
        XCTAssertEqual(decoded.substep?.duration, 15)
        XCTAssertEqual(decoded.tempDuration?.first?.duration, 540)
        XCTAssertEqual(decoded.tempDuration?.first?.units, .celsius)
    }

    func testTagsCompareByTitleOnly() {
        let left = Tag(title: "Acid", storedColor: "FF0000")
        let right = Tag(title: "Acid", storedColor: "00FF00")

        XCTAssertEqual(left, right)
    }
}
