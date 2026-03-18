import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for axis parameter validation
/// **Feature: ps5-gamepad-mapper, Property 5: Axis Parameter Validation**
final class AxisParameterValidationPropertyTests: XCTestCase {
    
    // MARK: - Property 5: Axis Parameter Validation
    
    /// **Feature: ps5-gamepad-mapper, Property 5: Axis Parameter Validation**
    /// **Validates: Requirements 6.2, 6.3**
    ///
    /// *For any* axis-to-mouse mapping configuration:
    /// - Sensitivity values outside the range 0.1 to 10.0 SHALL be rejected
    /// - Deadzone values outside the range 0.0 to 0.5 SHALL be rejected
    func testAxisParameterValidation_InvalidSensitivity() {
        property("Sensitivity values outside 0.1-10.0 are rejected") <- forAll { (value: Double) in
            // Only test values outside the valid range
            guard value < 0.1 || value > 10.0 else { return true }
            
            let error = AxisConfig.validateSensitivity(value)
            
            // Should return an error for invalid values
            guard let validationError = error else { return false }
            
            // Error should be the correct type
            if case .invalidSensitivity(let errorValue) = validationError {
                return errorValue == value
            }
            return false
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 5: Axis Parameter Validation**
    /// **Validates: Requirements 6.2, 6.3**
    func testAxisParameterValidation_ValidSensitivity() {
        property("Sensitivity values within 0.1-10.0 are accepted") <- forAll { (percent: Int) in
            // Generate values within valid range (0.1 to 10.0)
            let value = 0.1 + (Double(abs(percent) % 100) / 100.0) * 9.9
            
            let error = AxisConfig.validateSensitivity(value)
            
            // Should return nil for valid values
            return error == nil
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 5: Axis Parameter Validation**
    /// **Validates: Requirements 6.2, 6.3**
    func testAxisParameterValidation_InvalidDeadzone() {
        property("Deadzone values outside 0.0-0.5 are rejected") <- forAll { (value: Double) in
            // Only test values outside the valid range
            guard value < 0.0 || value > 0.5 else { return true }
            
            let error = AxisConfig.validateDeadzone(value)
            
            // Should return an error for invalid values
            guard let validationError = error else { return false }
            
            // Error should be the correct type
            if case .invalidDeadzone(let errorValue) = validationError {
                return errorValue == value
            }
            return false
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 5: Axis Parameter Validation**
    /// **Validates: Requirements 6.2, 6.3**
    func testAxisParameterValidation_ValidDeadzone() {
        property("Deadzone values within 0.0-0.5 are accepted") <- forAll { (percent: Int) in
            // Generate values within valid range (0.0 to 0.5)
            let value = Double(abs(percent) % 51) / 100.0
            
            let error = AxisConfig.validateDeadzone(value)
            
            // Should return nil for valid values
            return error == nil
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 5: Axis Parameter Validation**
    /// **Validates: Requirements 6.2, 6.3**
    ///
    /// Test that validated initializer throws for invalid parameters
    func testAxisParameterValidation_ValidatedInitializer() {
        property("Validated initializer rejects invalid parameters") <- forAll { (deadzone: Double, sensitivity: Double) in
            let deadzoneValid = deadzone >= 0.0 && deadzone <= 0.5
            let sensitivityValid = sensitivity >= 0.1 && sensitivity <= 10.0
            
            do {
                let _ = try AxisConfig.validated(deadzone: deadzone, sensitivity: sensitivity)
                // If we get here, both should be valid
                return deadzoneValid && sensitivityValid
            } catch {
                // If we get an error, at least one should be invalid
                return !deadzoneValid || !sensitivityValid
            }
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 5: Axis Parameter Validation**
    /// **Validates: Requirements 6.2, 6.3**
    ///
    /// Test boundary values
    func testAxisParameterValidation_BoundaryValues() {
        // Test exact boundary values for sensitivity
        XCTAssertNil(AxisConfig.validateSensitivity(0.1), "0.1 should be valid")
        XCTAssertNil(AxisConfig.validateSensitivity(10.0), "10.0 should be valid")
        XCTAssertNotNil(AxisConfig.validateSensitivity(0.09), "0.09 should be invalid")
        XCTAssertNotNil(AxisConfig.validateSensitivity(10.01), "10.01 should be invalid")
        
        // Test exact boundary values for deadzone
        XCTAssertNil(AxisConfig.validateDeadzone(0.0), "0.0 should be valid")
        XCTAssertNil(AxisConfig.validateDeadzone(0.5), "0.5 should be valid")
        XCTAssertNotNil(AxisConfig.validateDeadzone(-0.01), "-0.01 should be invalid")
        XCTAssertNotNil(AxisConfig.validateDeadzone(0.51), "0.51 should be invalid")
    }
}
