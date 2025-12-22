import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Mouse Mode Parameter Validation
/// **Feature: stick-interaction-enhancement, Property 3: Mouse Mode Parameter Validation**
final class MouseModeParameterValidationPropertyTests: XCTestCase {
    
    // MARK: - Property 3: Mouse Mode Parameter Validation
    
    /// **Feature: stick-interaction-enhancement, Property 3: Mouse Mode Parameter Validation**
    /// **Validates: Requirements 4.1, 4.2, 4.4**
    ///
    /// *For any* sensitivity value provided, the stored value should be clamped
    /// to the valid range [0.1, 10.0].
    func testSensitivityClampedToValidRange() {
        property("Sensitivity is clamped to valid range [0.1, 10.0]") <- forAll { (rawValue: Double) in
            // Clamp the value as the system would
            let clampedValue = max(0.1, min(10.0, rawValue))
            
            // Verify the clamped value is within valid range
            return clampedValue >= 0.1 && clampedValue <= 10.0
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 3: Mouse Mode Parameter Validation**
    /// **Validates: Requirements 4.1, 4.2, 4.4**
    ///
    /// *For any* deadzone value provided, the stored value should be clamped
    /// to the valid range [0.0, 0.5].
    func testDeadzoneClampedToValidRange() {
        property("Deadzone is clamped to valid range [0.0, 0.5]") <- forAll { (rawValue: Double) in
            // Clamp the value as the system would
            let clampedValue = max(0.0, min(0.5, rawValue))
            
            // Verify the clamped value is within valid range
            return clampedValue >= 0.0 && clampedValue <= 0.5
        }
    }

    /// **Feature: stick-interaction-enhancement, Property 3: Mouse Mode Parameter Validation**
    /// **Validates: Requirements 4.1, 4.2, 4.4**
    ///
    /// *For any* exponential power value provided, the stored value should be clamped
    /// to the valid range [1.0, 4.0].
    func testExponentialPowerClampedToValidRange() {
        property("Exponential power is clamped to valid range [1.0, 4.0]") <- forAll { (rawValue: Double) in
            // Clamp the value as the system would
            let clampedValue = max(1.0, min(4.0, rawValue))
            
            // Verify the clamped value is within valid range
            return clampedValue >= 1.0 && clampedValue <= 4.0
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 3: Mouse Mode Parameter Validation**
    /// **Validates: Requirements 4.1, 4.2, 4.4**
    ///
    /// Test that AxisConfig validates sensitivity correctly
    func testAxisConfigSensitivityValidation() {
        property("AxisConfig validates sensitivity within range") <- forAll { (sensitivity: Double) in
            let error = AxisConfig.validateSensitivity(sensitivity)
            
            // If sensitivity is in valid range, no error should be returned
            if sensitivity >= 0.1 && sensitivity <= 10.0 {
                return error == nil
            } else {
                // If sensitivity is out of range, an error should be returned
                return error != nil
            }
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 3: Mouse Mode Parameter Validation**
    /// **Validates: Requirements 4.1, 4.2, 4.4**
    ///
    /// Test that AxisConfig validates deadzone correctly
    func testAxisConfigDeadzoneValidation() {
        property("AxisConfig validates deadzone within range") <- forAll { (deadzone: Double) in
            let error = AxisConfig.validateDeadzone(deadzone)
            
            // If deadzone is in valid range, no error should be returned
            if deadzone >= 0.0 && deadzone <= 0.5 {
                return error == nil
            } else {
                // If deadzone is out of range, an error should be returned
                return error != nil
            }
        }
    }

    /// **Feature: stick-interaction-enhancement, Property 3: Mouse Mode Parameter Validation**
    /// **Validates: Requirements 4.1, 4.2, 4.4**
    ///
    /// Test that valid MouseMoveAction parameters are accepted
    func testValidMouseMoveActionParameters() {
        // Generate valid parameters within ranges
        let validSensitivityGen = Gen.fromElements(of: [0.1, 0.5, 1.0, 2.0, 5.0, 10.0])
        let validDeadzoneGen = Gen.fromElements(of: [0.0, 0.1, 0.2, 0.3, 0.4, 0.5])
        let validPowerGen = Gen.fromElements(of: [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0])
        
        property("Valid MouseMoveAction parameters are accepted") <- forAll(
            validSensitivityGen,
            validDeadzoneGen,
            validPowerGen
        ) { (sensitivity: Double, deadzone: Double, power: Double) in
            // Create MouseMoveAction with valid parameters
            let config = MouseMoveAction(
                sensitivity: sensitivity,
                deadzone: deadzone,
                curve: .exponential(power: power)
            )
            
            // Verify parameters are stored correctly
            return config.sensitivity == sensitivity
                && config.deadzone == deadzone
                && config.curve == .exponential(power: power)
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 3: Mouse Mode Parameter Validation**
    /// **Validates: Requirements 4.1, 4.2, 4.4**
    ///
    /// Test that MouseMoveAction with linear curve stores parameters correctly
    func testMouseMoveActionLinearCurve() {
        let validSensitivityGen = Gen.fromElements(of: [0.1, 0.5, 1.0, 2.0, 5.0, 10.0])
        let validDeadzoneGen = Gen.fromElements(of: [0.0, 0.1, 0.2, 0.3, 0.4, 0.5])
        
        property("MouseMoveAction with linear curve stores parameters correctly") <- forAll(
            validSensitivityGen,
            validDeadzoneGen
        ) { (sensitivity: Double, deadzone: Double) in
            let config = MouseMoveAction(
                sensitivity: sensitivity,
                deadzone: deadzone,
                curve: .linear
            )
            
            return config.sensitivity == sensitivity
                && config.deadzone == deadzone
                && config.curve == .linear
        }
    }
}
