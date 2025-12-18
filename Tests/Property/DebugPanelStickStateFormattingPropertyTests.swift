import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for debug panel stick state formatting
/// **Feature: stick-direction-mapping, Property 10: Debug Panel Stick State Formatting**
final class DebugPanelStickStateFormattingPropertyTests: XCTestCase {
    
    // MARK: - Property 10: Debug Panel Stick State Formatting
    
    /// **Feature: stick-direction-mapping, Property 10: Debug Panel Stick State Formatting**
    /// **Validates: Requirements 8.2, 8.3**
    ///
    /// *For any* stick position, the debug panel should display the angle in degrees (0-360)
    /// and magnitude as a value between 0.0 and 1.0 with appropriate precision.
    func testAngleFormattingShowsDegrees() {
        property("Angle formatting shows degrees with 1 decimal place") <- forAll { (position: StickPosition) in
            let formatted = DebugPanelAxisFormatter.formatAngle(position.angle)
            
            // Should end with degree symbol
            guard formatted.hasSuffix("°") else { return false }
            
            // Should have exactly 1 decimal place before the degree symbol
            let withoutDegree = String(formatted.dropLast())
            return Self.hasExactlyOneDecimalPlace(withoutDegree)
        }
    }
    
    /// **Feature: stick-direction-mapping, Property 10: Debug Panel Stick State Formatting**
    /// **Validates: Requirements 8.2**
    ///
    /// Test that angle is normalized to 0-360 range
    func testAngleNormalization() {
        property("Angle is normalized to 0-360 range") <- forAll { (rawAngle: Double) in
            let formatted = DebugPanelAxisFormatter.formatAngle(rawAngle)
            
            // Extract numeric value
            let withoutDegree = String(formatted.dropLast())
            guard let angle = Double(withoutDegree) else { return false }
            
            // Should be in valid range
            return angle >= 0.0 && angle < 360.0
        }
    }
    
    /// **Feature: stick-direction-mapping, Property 10: Debug Panel Stick State Formatting**
    /// **Validates: Requirements 8.3**
    ///
    /// Test that magnitude is formatted with 2 decimal places
    func testMagnitudeFormattingPrecision() {
        property("Magnitude formatting shows exactly 2 decimal places") <- forAll { (position: StickPosition) in
            let formatted = DebugPanelAxisFormatter.formatMagnitude(position.magnitude)
            return Self.hasExactlyTwoDecimalPlaces(formatted)
        }
    }
    
    /// **Feature: stick-direction-mapping, Property 10: Debug Panel Stick State Formatting**
    /// **Validates: Requirements 8.3**
    ///
    /// Test that magnitude is clamped to 0.0-1.0 range for display
    func testMagnitudeClampedToDisplayRange() {
        property("Magnitude is clamped to 0.0-1.0 for display") <- forAll { (position: StickPosition) in
            let formatted = DebugPanelAxisFormatter.formatMagnitude(position.magnitude)
            guard let value = Double(formatted) else { return false }
            
            // Should be in valid display range
            return value >= 0.0 && value <= 1.0
        }
    }

    
    /// **Feature: stick-direction-mapping, Property 10: Debug Panel Stick State Formatting**
    /// **Validates: Requirements 8.2, 8.3**
    ///
    /// Test complete stick state formatting
    func testCompleteStickStateFormatting() {
        property("Complete stick state formatting includes all components") <- forAll { (position: StickPosition) in
            let direction = position.magnitude > 0.5 ? StickDirection.up.rawValue : nil
            let formatted = DebugPanelAxisFormatter.formatStickState(
                direction: direction,
                angle: position.angle,
                magnitude: position.magnitude
            )
            
            // Should contain separator
            guard formatted.contains("|") else { return false }
            
            // Should contain degree symbol for angle
            guard formatted.contains("°") else { return false }
            
            // Should contain direction or "None"
            let hasDirection = direction != nil ? formatted.contains(direction!) : formatted.contains("None")
            return hasDirection
        }
    }
    
    /// **Feature: stick-direction-mapping, Property 10: Debug Panel Stick State Formatting**
    /// **Validates: Requirements 8.2, 8.3**
    ///
    /// Test formatting consistency (same input always produces same output)
    func testFormattingConsistency() {
        property("Formatting is deterministic") <- forAll { (position: StickPosition) in
            let formatted1 = DebugPanelAxisFormatter.formatAngle(position.angle)
            let formatted2 = DebugPanelAxisFormatter.formatAngle(position.angle)
            
            let mag1 = DebugPanelAxisFormatter.formatMagnitude(position.magnitude)
            let mag2 = DebugPanelAxisFormatter.formatMagnitude(position.magnitude)
            
            return formatted1 == formatted2 && mag1 == mag2
        }
    }
    
    /// **Feature: stick-direction-mapping, Property 10: Debug Panel Stick State Formatting**
    /// **Validates: Requirements 8.2**
    ///
    /// Test edge case angles
    func testEdgeCaseAngles() {
        let edgeCases: [Double] = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0, 359.9, 360.0, -45.0, 720.0]
        
        for angle in edgeCases {
            let formatted = DebugPanelAxisFormatter.formatAngle(angle)
            
            // Should end with degree symbol
            XCTAssertTrue(formatted.hasSuffix("°"), "Angle \(angle) formatted as '\(formatted)' should end with °")
            
            // Extract numeric value
            let withoutDegree = String(formatted.dropLast())
            guard let normalizedAngle = Double(withoutDegree) else {
                XCTFail("Could not parse angle from '\(formatted)'")
                continue
            }
            
            // Should be in valid range
            XCTAssertTrue(
                normalizedAngle >= 0.0 && normalizedAngle < 360.0,
                "Angle \(angle) normalized to \(normalizedAngle) should be in [0, 360)"
            )
        }
    }
    
    /// **Feature: stick-direction-mapping, Property 10: Debug Panel Stick State Formatting**
    /// **Validates: Requirements 8.3**
    ///
    /// Test edge case magnitudes
    func testEdgeCaseMagnitudes() {
        let edgeCases: [Double] = [0.0, 0.01, 0.5, 0.99, 1.0, 1.414, -0.5, 2.0]
        
        for magnitude in edgeCases {
            let formatted = DebugPanelAxisFormatter.formatMagnitude(magnitude)
            
            // Should have exactly 2 decimal places
            XCTAssertTrue(
                Self.hasExactlyTwoDecimalPlaces(formatted),
                "Magnitude \(magnitude) formatted as '\(formatted)' should have exactly 2 decimal places"
            )
            
            // Should be clamped to display range
            guard let value = Double(formatted) else {
                XCTFail("Could not parse magnitude from '\(formatted)'")
                continue
            }
            
            XCTAssertTrue(
                value >= 0.0 && value <= 1.0,
                "Magnitude \(magnitude) formatted as \(value) should be in [0.0, 1.0]"
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if a string has exactly 1 decimal place
    private static func hasExactlyOneDecimalPlace(_ string: String) -> Bool {
        guard let decimalIndex = string.firstIndex(of: ".") else {
            return false
        }
        
        let afterDecimal = string[string.index(after: decimalIndex)...]
        return afterDecimal.count == 1 && afterDecimal.allSatisfy { $0.isNumber }
    }
    
    /// Check if a string has exactly 2 decimal places
    private static func hasExactlyTwoDecimalPlaces(_ string: String) -> Bool {
        guard let decimalIndex = string.firstIndex(of: ".") else {
            return false
        }
        
        let afterDecimal = string[string.index(after: decimalIndex)...]
        return afterDecimal.count == 2 && afterDecimal.allSatisfy { $0.isNumber }
    }
}
