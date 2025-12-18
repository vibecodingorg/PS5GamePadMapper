import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for deadzone processing
/// **Feature: ps5-gamepad-mapper, Property 2: Deadzone Zeroing**
final class DeadzonePropertyTests: XCTestCase {
    
    private var inputProcessor: InputProcessor!
    
    override func setUp() {
        super.setUp()
        inputProcessor = InputProcessor()
    }
    
    override func tearDown() {
        inputProcessor = nil
        super.tearDown()
    }
    
    // MARK: - Property 2: Deadzone Zeroing
    
    /// **Feature: ps5-gamepad-mapper, Property 2: Deadzone Zeroing**
    /// **Validates: Requirements 3.4**
    ///
    /// *For any* axis input value that falls within the configured deadzone threshold,
    /// the processed output SHALL be exactly zero.
    func testDeadzoneZeroing_Sticks() {
        property("Stick values within deadzone produce zero output") <- forAll { (deadzone: Double) in
            // Only test valid deadzone values
            guard deadzone >= 0.0 && deadzone <= 0.5 else { return true }
            
            let config = AxisConfig(deadzone: deadzone, sensitivity: 1.0, curve: .linear)
            
            // Generate raw values that should be within deadzone after normalization
            // For sticks: normalized range is -1.0 to 1.0
            // A raw value of 0 normalizes to 0.0, which is always within any deadzone
            let zeroInput = RawAxisInput(axis: .leftStickX, rawValue: 0, timestamp: 0)
            let result = self.inputProcessor.processAxisInput(zeroInput, config: config)
            
            return result.normalizedValue == 0.0
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 2: Deadzone Zeroing**
    /// **Validates: Requirements 3.4**
    func testDeadzoneZeroing_Triggers() {
        property("Trigger values within deadzone produce zero output") <- forAll { (deadzone: Double) in
            // Only test valid deadzone values
            guard deadzone >= 0.0 && deadzone <= 0.5 else { return true }
            
            let config = AxisConfig(deadzone: deadzone, sensitivity: 1.0, curve: .linear)
            
            // A raw value of 0 for triggers normalizes to 0.0, which is always within any deadzone
            let zeroInput = RawAxisInput(axis: .l2Trigger, rawValue: 0, timestamp: 0)
            let result = self.inputProcessor.processAxisInput(zeroInput, config: config)
            
            return result.normalizedValue == 0.0
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 2: Deadzone Zeroing**
    /// **Validates: Requirements 3.4**
    ///
    /// Test that small stick values within deadzone produce zero
    func testDeadzoneZeroing_SmallStickValues() {
        property("Small stick values within deadzone produce zero") <- forAll { (deadzonePercent: Int) in
            // Generate deadzone between 0.1 and 0.5
            let deadzone = Double(max(1, min(5, deadzonePercent))) / 10.0
            let config = AxisConfig(deadzone: deadzone, sensitivity: 1.0, curve: .linear)
            
            // Generate a raw value that will normalize to less than deadzone
            // For sticks: raw value of 3276 normalizes to ~0.1 (3276/32767)
            // So if deadzone is 0.2, a raw value of 3276 should produce 0
            let halfDeadzoneRaw = Int16(deadzone * 0.5 * 32767.0)
            let input = RawAxisInput(axis: .leftStickX, rawValue: halfDeadzoneRaw, timestamp: 0)
            let result = self.inputProcessor.processAxisInput(input, config: config)
            
            return result.normalizedValue == 0.0
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 2: Deadzone Zeroing**
    /// **Validates: Requirements 3.4**
    ///
    /// Test that small trigger values within deadzone produce zero
    func testDeadzoneZeroing_SmallTriggerValues() {
        property("Small trigger values within deadzone produce zero") <- forAll { (deadzonePercent: Int) in
            // Generate deadzone between 0.1 and 0.5
            let deadzone = Double(max(1, min(5, deadzonePercent))) / 10.0
            let config = AxisConfig(deadzone: deadzone, sensitivity: 1.0, curve: .linear)
            
            // Generate a raw value that will normalize to less than deadzone
            // For triggers: raw value of 25 normalizes to ~0.1 (25/255)
            let halfDeadzoneRaw = Int16(deadzone * 0.5 * 255.0)
            let input = RawAxisInput(axis: .l2Trigger, rawValue: halfDeadzoneRaw, timestamp: 0)
            let result = self.inputProcessor.processAxisInput(input, config: config)
            
            return result.normalizedValue == 0.0
        }
    }
}
