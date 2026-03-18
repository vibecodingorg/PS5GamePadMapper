import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for response curve behavior
/// **Feature: ps5-gamepad-mapper, Property 6: Response Curve Behavior**
final class ResponseCurvePropertyTests: XCTestCase {
    
    private var inputProcessor: InputProcessor!
    
    override func setUp() {
        super.setUp()
        inputProcessor = InputProcessor()
    }
    
    override func tearDown() {
        inputProcessor = nil
        super.tearDown()
    }
    
    // MARK: - Property 6: Response Curve Behavior
    
    /// **Feature: ps5-gamepad-mapper, Property 6: Response Curve Behavior**
    /// **Validates: Requirements 6.4**
    ///
    /// *For any* axis input with configured response curve:
    /// - Linear curve SHALL produce output proportional to input (output = input * sensitivity)
    func testResponseCurveBehavior_Linear() {
        property("Linear curve produces proportional output") <- forAll { (wrapper: StickAxisInput) in
            let sensitivity = 1.0
            let config = AxisConfig(deadzone: 0.0, sensitivity: sensitivity, curve: .linear)
            
            let result = self.inputProcessor.processAxisInput(wrapper.input, config: config)
            
            // Calculate expected normalized value
            let rawValue = wrapper.input.rawValue
            let expectedNormalized: Double
            if rawValue >= 0 {
                expectedNormalized = Double(rawValue) / 32767.0
            } else {
                expectedNormalized = Double(rawValue) / 32768.0
            }
            
            // With linear curve and sensitivity 1.0, output should equal normalized input
            // Allow small floating point tolerance
            return abs(result.normalizedValue - expectedNormalized) < 0.0001
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 6: Response Curve Behavior**
    /// **Validates: Requirements 6.4**
    ///
    /// Linear curve with sensitivity should scale proportionally
    func testResponseCurveBehavior_LinearWithSensitivity() {
        property("Linear curve scales with sensitivity") <- forAll { (sensitivityPercent: Int) in
            // Generate sensitivity between 0.1 and 2.0 (to avoid clamping issues)
            let sensitivity = 0.1 + (Double(abs(sensitivityPercent) % 20) / 10.0)
            let config = AxisConfig(deadzone: 0.0, sensitivity: sensitivity, curve: .linear)
            
            // Use a moderate raw value to avoid clamping
            let rawValue: Int16 = 16383  // ~0.5 normalized
            let input = RawAxisInput(axis: .leftStickX, rawValue: rawValue, timestamp: 0)
            
            let result = self.inputProcessor.processAxisInput(input, config: config)
            
            // Expected: normalized * sensitivity, clamped to [-1, 1]
            let normalized = Double(rawValue) / 32767.0
            let expected = min(1.0, max(-1.0, normalized * sensitivity))
            
            return abs(result.normalizedValue - expected) < 0.0001
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 6: Response Curve Behavior**
    /// **Validates: Requirements 6.4**
    ///
    /// - Exponential curve SHALL produce output following the power function
    ///   (output = sign(input) * |input|^power * sensitivity)
    func testResponseCurveBehavior_Exponential() {
        property("Exponential curve applies power function") <- forAll { (powerIndex: Int) in
            // Generate power between 1.0 and 3.0
            let power = 1.0 + Double(abs(powerIndex) % 21) / 10.0
            let config = AxisConfig(deadzone: 0.0, sensitivity: 1.0, curve: .exponential(power: power))
            
            // Use a moderate raw value
            let rawValue: Int16 = 16383  // ~0.5 normalized
            let input = RawAxisInput(axis: .leftStickX, rawValue: rawValue, timestamp: 0)
            
            let result = self.inputProcessor.processAxisInput(input, config: config)
            
            // Expected: sign(normalized) * |normalized|^power
            let normalized = Double(rawValue) / 32767.0
            let expected = pow(abs(normalized), power)  // positive value, so sign is 1
            
            return abs(result.normalizedValue - expected) < 0.0001
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 6: Response Curve Behavior**
    /// **Validates: Requirements 6.4**
    ///
    /// Exponential curve should preserve sign for negative values
    func testResponseCurveBehavior_ExponentialPreservesSign() {
        property("Exponential curve preserves sign for negative values") <- forAll { (powerIndex: Int) in
            // Generate power between 1.0 and 3.0
            let power = 1.0 + Double(abs(powerIndex) % 21) / 10.0
            let config = AxisConfig(deadzone: 0.0, sensitivity: 1.0, curve: .exponential(power: power))
            
            // Use a negative raw value
            let rawValue: Int16 = -16384  // ~-0.5 normalized
            let input = RawAxisInput(axis: .leftStickX, rawValue: rawValue, timestamp: 0)
            
            let result = self.inputProcessor.processAxisInput(input, config: config)
            
            // Expected: -1 * |normalized|^power (negative sign preserved)
            let normalized = Double(rawValue) / 32768.0
            let expected = -pow(abs(normalized), power)
            
            return abs(result.normalizedValue - expected) < 0.0001
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 6: Response Curve Behavior**
    /// **Validates: Requirements 6.4**
    ///
    /// Exponential curve for triggers (0.0 to 1.0 range)
    func testResponseCurveBehavior_ExponentialTrigger() {
        property("Exponential curve works for triggers") <- forAll { (powerIndex: Int) in
            // Generate power between 1.0 and 3.0
            let power = 1.0 + Double(abs(powerIndex) % 21) / 10.0
            let config = AxisConfig(deadzone: 0.0, sensitivity: 1.0, curve: .exponential(power: power))
            
            // Use a moderate trigger value
            let rawValue: Int16 = 127  // ~0.5 normalized for trigger
            let input = RawAxisInput(axis: .l2Trigger, rawValue: rawValue, timestamp: 0)
            
            let result = self.inputProcessor.processAxisInput(input, config: config)
            
            // Expected: normalized^power (triggers are always positive)
            let normalized = Double(rawValue) / 255.0
            let expected = pow(normalized, power)
            
            return abs(result.normalizedValue - expected) < 0.001
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 6: Response Curve Behavior**
    /// **Validates: Requirements 6.4**
    ///
    /// Zero input should always produce zero output regardless of curve
    func testResponseCurveBehavior_ZeroInput() {
        property("Zero input produces zero output for any curve") <- forAll { (curve: ResponseCurve) in
            let config = AxisConfig(deadzone: 0.0, sensitivity: 1.0, curve: curve)
            
            let input = RawAxisInput(axis: .leftStickX, rawValue: 0, timestamp: 0)
            let result = self.inputProcessor.processAxisInput(input, config: config)
            
            return result.normalizedValue == 0.0
        }
    }
}
