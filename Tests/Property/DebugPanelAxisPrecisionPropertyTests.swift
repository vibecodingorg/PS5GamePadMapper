import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for debug panel axis precision
/// **Feature: ps5-gamepad-mapper, Property 17: Debug Panel Axis Precision**
final class DebugPanelAxisPrecisionPropertyTests: XCTestCase {
    
    // MARK: - Property 17: Debug Panel Axis Precision
    
    /// **Feature: ps5-gamepad-mapper, Property 17: Debug Panel Axis Precision**
    /// **Validates: Requirements 15.4**
    ///
    /// *For any* axis value displayed in the debug panel, the displayed string
    /// SHALL show exactly 2 decimal places of precision.
    func testAxisValueDisplayPrecision() {
        property("Axis value formatting shows exactly 2 decimal places") <- forAll { (value: Double) in
            // Clamp to valid axis range for realistic testing
            let clampedValue = max(-1.0, min(1.0, value))
            let formatted = DebugPanelAxisFormatter.formatAxisValue(clampedValue)
            
            // Check format: should match pattern like "-1.00", "0.50", "1.00"
            return Self.hasExactlyTwoDecimalPlaces(formatted)
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 17: Debug Panel Axis Precision**
    /// **Validates: Requirements 15.4**
    ///
    /// Test with normalized stick axis values (-1.0 to 1.0)
    func testStickAxisValuePrecision() {
        property("Stick axis values show exactly 2 decimal places") <- forAll { (wrapper: StickAxisInput) in
            let inputProcessor = InputProcessor()
            let config = AxisConfig(deadzone: 0.0, sensitivity: 1.0, curve: .linear)
            let result = inputProcessor.processAxisInput(wrapper.input, config: config)
            
            let formatted = DebugPanelAxisFormatter.formatAxisValue(result.normalizedValue)
            return Self.hasExactlyTwoDecimalPlaces(formatted)
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 17: Debug Panel Axis Precision**
    /// **Validates: Requirements 15.4**
    ///
    /// Test with normalized trigger axis values (0.0 to 1.0)
    func testTriggerAxisValuePrecision() {
        property("Trigger axis values show exactly 2 decimal places") <- forAll { (wrapper: TriggerAxisInput) in
            let inputProcessor = InputProcessor()
            let config = AxisConfig(deadzone: 0.0, sensitivity: 1.0, curve: .linear)
            let result = inputProcessor.processAxisInput(wrapper.input, config: config)
            
            let formatted = DebugPanelAxisFormatter.formatAxisValue(result.normalizedValue)
            return Self.hasExactlyTwoDecimalPlaces(formatted)
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 17: Debug Panel Axis Precision**
    /// **Validates: Requirements 15.4**
    ///
    /// Test edge cases: exactly 0, 1, -1
    func testEdgeCaseAxisValues() {
        let edgeCases: [Double] = [0.0, 1.0, -1.0, 0.5, -0.5, 0.01, -0.01, 0.99, -0.99]
        
        for value in edgeCases {
            let formatted = DebugPanelAxisFormatter.formatAxisValue(value)
            XCTAssertTrue(
                Self.hasExactlyTwoDecimalPlaces(formatted),
                "Value \(value) formatted as '\(formatted)' should have exactly 2 decimal places"
            )
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 17: Debug Panel Axis Precision**
    /// **Validates: Requirements 15.4**
    ///
    /// Test that formatting is consistent (same input always produces same output)
    func testFormattingConsistency() {
        property("Formatting is deterministic") <- forAll { (value: Double) in
            let clampedValue = max(-1.0, min(1.0, value))
            let formatted1 = DebugPanelAxisFormatter.formatAxisValue(clampedValue)
            let formatted2 = DebugPanelAxisFormatter.formatAxisValue(clampedValue)
            return formatted1 == formatted2
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if a string has exactly 2 decimal places
    /// Valid formats: "0.00", "-1.00", "0.50", etc.
    private static func hasExactlyTwoDecimalPlaces(_ string: String) -> Bool {
        // Find the decimal point
        guard let decimalIndex = string.firstIndex(of: ".") else {
            return false
        }
        
        // Count characters after decimal point
        let afterDecimal = string[string.index(after: decimalIndex)...]
        
        // Should have exactly 2 digits after decimal
        return afterDecimal.count == 2 && afterDecimal.allSatisfy { $0.isNumber }
    }
}
