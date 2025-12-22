import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for mouse mode deadzone filtering
/// **Feature: stick-interaction-enhancement, Property 5: Deadzone Filtering**
final class MouseDeadzoneFilteringPropertyTests: XCTestCase {
    
    private var inputProcessor: InputProcessor!
    
    override func setUp() {
        super.setUp()
        inputProcessor = InputProcessor()
    }
    
    override func tearDown() {
        inputProcessor = nil
        super.tearDown()
    }
    
    // MARK: - Property 5: Deadzone Filtering
    
    /// **Feature: stick-interaction-enhancement, Property 5: Deadzone Filtering**
    /// **Validates: Requirements 4.6**
    ///
    /// *For any* stick position (x, y) with magnitude less than or equal to the configured deadzone,
    /// no mouse movement events should be emitted (output should be zero).
    func testDeadzoneFilteringProducesZeroOutput() {
        property("Stick values within deadzone produce zero output") <- forAll { (deadzonePercent: Int) in
            // Generate deadzone between 0.1 and 0.5
            let deadzone = Double(max(1, min(5, deadzonePercent))) / 10.0
            let config = AxisConfig(deadzone: deadzone, sensitivity: 1.0, curve: .linear)
            
            // Generate a raw value that will normalize to less than deadzone
            // For sticks: raw value of 3276 normalizes to ~0.1 (3276/32767)
            let halfDeadzoneRaw = Int16(deadzone * 0.5 * 32767.0)
            let input = RawAxisInput(axis: .leftStickX, rawValue: halfDeadzoneRaw, timestamp: 0)
            let result = self.inputProcessor.processAxisInput(input, config: config)
            
            return result.normalizedValue == 0.0
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 5: Deadzone Filtering**
    /// **Validates: Requirements 4.6**
    ///
    /// Test that values exactly at the deadzone boundary produce zero output
    func testDeadzoneAtBoundaryProducesZeroOutput() {
        property("Stick values at deadzone boundary produce zero output") <- forAll { (deadzonePercent: Int) in
            // Generate deadzone between 0.1 and 0.5
            let deadzone = Double(max(1, min(5, deadzonePercent))) / 10.0
            let config = AxisConfig(deadzone: deadzone, sensitivity: 1.0, curve: .linear)
            
            // Generate a raw value that will normalize to exactly the deadzone
            let atDeadzoneRaw = Int16(deadzone * 32767.0)
            let input = RawAxisInput(axis: .leftStickX, rawValue: atDeadzoneRaw, timestamp: 0)
            let result = self.inputProcessor.processAxisInput(input, config: config)
            
            return result.normalizedValue == 0.0
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 5: Deadzone Filtering**
    /// **Validates: Requirements 4.6**
    ///
    /// Test that values outside the deadzone produce non-zero output
    func testValuesOutsideDeadzoneProduceNonZeroOutput() {
        property("Stick values outside deadzone produce non-zero output") <- forAll { (deadzonePercent: Int) in
            // Generate deadzone between 0.1 and 0.4 (leave room for values outside)
            let deadzone = Double(max(1, min(4, deadzonePercent))) / 10.0
            let config = AxisConfig(deadzone: deadzone, sensitivity: 1.0, curve: .linear)
            
            // Generate a raw value that will normalize to significantly more than deadzone
            let outsideDeadzoneRaw = Int16((deadzone + 0.3) * 32767.0)
            let input = RawAxisInput(axis: .leftStickX, rawValue: outsideDeadzoneRaw, timestamp: 0)
            let result = self.inputProcessor.processAxisInput(input, config: config)
            
            return result.normalizedValue > 0.0
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 5: Deadzone Filtering**
    /// **Validates: Requirements 4.6**
    ///
    /// Test that negative values within deadzone also produce zero output
    func testNegativeValuesWithinDeadzoneProduceZeroOutput() {
        property("Negative stick values within deadzone produce zero output") <- forAll { (deadzonePercent: Int) in
            // Generate deadzone between 0.1 and 0.5
            let deadzone = Double(max(1, min(5, deadzonePercent))) / 10.0
            let config = AxisConfig(deadzone: deadzone, sensitivity: 1.0, curve: .linear)
            
            // Generate a negative raw value that will normalize to less than deadzone
            let halfDeadzoneRaw = Int16(-deadzone * 0.5 * 32768.0)
            let input = RawAxisInput(axis: .leftStickX, rawValue: halfDeadzoneRaw, timestamp: 0)
            let result = self.inputProcessor.processAxisInput(input, config: config)
            
            return result.normalizedValue == 0.0
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 5: Deadzone Filtering**
    /// **Validates: Requirements 4.6**
    ///
    /// Test that zero input always produces zero output regardless of deadzone
    func testZeroInputAlwaysProducesZeroOutput() {
        property("Zero input always produces zero output") <- forAll { (deadzonePercent: Int) in
            // Generate any valid deadzone
            let deadzone = Double(max(0, min(5, deadzonePercent))) / 10.0
            let config = AxisConfig(deadzone: deadzone, sensitivity: 1.0, curve: .linear)
            
            let input = RawAxisInput(axis: .leftStickX, rawValue: 0, timestamp: 0)
            let result = self.inputProcessor.processAxisInput(input, config: config)
            
            return result.normalizedValue == 0.0
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 5: Deadzone Filtering**
    /// **Validates: Requirements 4.6**
    ///
    /// Test that deadzone filtering works for both X and Y axes
    func testDeadzoneFilteringWorksForBothAxes() {
        property("Deadzone filtering works for both X and Y axes") <- forAll { (deadzonePercent: Int) in
            let deadzone = Double(max(1, min(5, deadzonePercent))) / 10.0
            let config = AxisConfig(deadzone: deadzone, sensitivity: 1.0, curve: .linear)
            
            let halfDeadzoneRaw = Int16(deadzone * 0.5 * 32767.0)
            
            // Test X axis
            let inputX = RawAxisInput(axis: .leftStickX, rawValue: halfDeadzoneRaw, timestamp: 0)
            let resultX = self.inputProcessor.processAxisInput(inputX, config: config)
            
            // Test Y axis
            let inputY = RawAxisInput(axis: .leftStickY, rawValue: halfDeadzoneRaw, timestamp: 0)
            let resultY = self.inputProcessor.processAxisInput(inputY, config: config)
            
            return resultX.normalizedValue == 0.0 && resultY.normalizedValue == 0.0
        }
    }
}
