import XCTest
@testable import MacPulse

final class MemoryPressureCalculatorTests: XCTestCase {
    func testPressureReturnsZeroWhenTotalIsMissing() {
        let pressure = MemoryPressureCalculator.pressure(
            for: MemoryPressureInput(
                total: 0,
                free: 0,
                inactive: 0,
                wired: 0,
                active: 0,
                compressed: 0,
                swapUsed: 0
            )
        )

        XCTAssertEqual(pressure, 0)
    }

    func testPressureIsLowWhenMemoryIsAvailableAndNoSwapIsUsed() {
        let pressure = MemoryPressureCalculator.pressure(
            for: MemoryPressureInput(
                total: 16_000,
                free: 5_000,
                inactive: 4_000,
                wired: 1_000,
                active: 4_000,
                compressed: 500,
                swapUsed: 0
            )
        )

        XCTAssertLessThan(pressure, 45)
    }

    func testPressureRisesWithCompressionAndSwap() {
        let moderate = MemoryPressureCalculator.pressure(
            for: MemoryPressureInput(
                total: 16_000,
                free: 3_000,
                inactive: 2_000,
                wired: 2_000,
                active: 7_000,
                compressed: 1_000,
                swapUsed: 0
            )
        )
        let pressured = MemoryPressureCalculator.pressure(
            for: MemoryPressureInput(
                total: 16_000,
                free: 500,
                inactive: 500,
                wired: 3_000,
                active: 8_000,
                compressed: 3_000,
                swapUsed: 4_000
            )
        )

        XCTAssertGreaterThan(pressured, moderate)
        XCTAssertGreaterThan(pressured, 80)
    }

    func testPressureIsClampedToOneHundred() {
        let pressure = MemoryPressureCalculator.pressure(
            for: MemoryPressureInput(
                total: 10_000,
                free: 0,
                inactive: 0,
                wired: 10_000,
                active: 10_000,
                compressed: 10_000,
                swapUsed: 10_000
            )
        )

        XCTAssertEqual(pressure, 100)
    }
}
