import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for axis normalization
/// **Feature: ps5-gamepad-mapper, Property 1: Axis Normalization Bounds**
final class AxisNormalizationPropertyTests: XCTestCase {
    
    private var inputProcessor: InputProcessor!
    
    override func setUp() {
        super.setUp()
        inputProcessor = InputProcessor()
    }
    
    override func tearDown() {
        inputProcessor = nil
        super.tearDown()
    }
    
    // MARK: - Property 1: Axis Normalization Bounds
    
    /// **Feature: ps5-gamepad-mapper, Property 1: Axis Normalization Bounds**
    /// **Validates: Requirements 3.2**
    ///
    /// *For any* raw axis input value, the normalized output SHALL be within the valid range:
    /// -1.0 to 1.0 for stick axes, and 0.0 to 1.0 for trigger axes.
    func testAxisNormalizationBounds_Sticks() {
        property("Stick axis normalization produces values in range -1.0 to 1.0") <- forAll { (wrapper: StickAxisInput) in
            let config = AxisConfig(deadzone: 0.0, sensitivity: 1.0, curve: .linear)
            let result = self.inputProcessor.processAxisInput(wrapper.input, config: config)
            
            return result.normalizedValue >= -1.0 && result.normalizedValue <= 1.0
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 1: Axis Normalization Bounds**
    /// **Validates: Requirements 3.2**
    func testAxisNormalizationBounds_Triggers() {
        property("Trigger axis normalization produces values in range 0.0 to 1.0") <- forAll { (wrapper: TriggerAxisInput) in
            let config = AxisConfig(deadzone: 0.0, sensitivity: 1.0, curve: .linear)
            let result = self.inputProcessor.processAxisInput(wrapper.input, config: config)
            
            return result.normalizedValue >= 0.0 && result.normalizedValue <= 1.0
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 1: Axis Normalization Bounds**
    /// **Validates: Requirements 3.2**
    ///
    /// Even with maximum sensitivity, output should be clamped to valid range
    func testAxisNormalizationBounds_WithSensitivity() {
        property("Axis normalization with sensitivity stays in valid range") <- forAll { (input: RawAxisInput, config: AxisConfig) in
            let result = self.inputProcessor.processAxisInput(input, config: config)
            
            if input.axis.isTrigger {
                return result.normalizedValue >= 0.0 && result.normalizedValue <= 1.0
            } else {
                return result.normalizedValue >= -1.0 && result.normalizedValue <= 1.0
            }
        }
    }
}
