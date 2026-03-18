import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for axis-to-key threshold behavior
/// **Feature: ps5-gamepad-mapper, Property 4: Axis-to-Key Threshold Behavior**
final class AxisToKeyThresholdPropertyTests: XCTestCase {
    
    private var mappingEngine: MappingEngine!
    
    override func setUp() {
        super.setUp()
        mappingEngine = MappingEngine()
        // Set up a minimal profile so handleAxisEvent works
        mappingEngine.activeProfile = Profile(name: "Test")
    }
    
    override func tearDown() {
        mappingEngine = nil
        super.tearDown()
    }
    
    // MARK: - Property 4: Axis-to-Key Threshold Behavior
    
    /// **Feature: ps5-gamepad-mapper, Property 4: Axis-to-Key Threshold Behavior**
    /// **Validates: Requirements 7.1, 7.2, 7.3**
    ///
    /// *For any* axis value that exceeds the positive threshold,
    /// the positive direction key SHALL be pressed.
    func testPositiveThresholdExceeded_EmitsKeyPress() {
        property("Axis value >= threshold emits positive key press") <- forAll(
            Self.thresholdGen,
            Self.stickAxisGen
        ) { (threshold: Double, axis: AxisType) in
            // Reset state
            self.mappingEngine.clearAxisToKeyConfigs()
            
            let positiveKey = KeyAction(keyCode: 0x00) // 'A' key
            let config = AxisToKeyConfig(
                positiveKey: positiveKey,
                negativeKey: nil,
                threshold: threshold
            )
            self.mappingEngine.setAxisToKeyConfig(config, for: axis)
            
            // Generate a value that exceeds the threshold
            let valueAboveThreshold = threshold + 0.01
            let event = AxisEvent(axis: axis, normalizedValue: valueAboveThreshold)
            
            let actions = self.mappingEngine.handleAxisEvent(event)
            
            // Should contain a keyPress action for the positive key
            let hasKeyPress = actions.contains { action in
                if case .keyPress(let key) = action {
                    return key == positiveKey
                }
                return false
            }
            
            return hasKeyPress
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 4: Axis-to-Key Threshold Behavior**
    /// **Validates: Requirements 7.1, 7.2, 7.3**
    ///
    /// *For any* axis value that exceeds the negative threshold,
    /// the negative direction key SHALL be pressed.
    func testNegativeThresholdExceeded_EmitsKeyPress() {
        property("Axis value <= -threshold emits negative key press") <- forAll(
            Self.thresholdGen,
            Self.stickAxisGen
        ) { (threshold: Double, axis: AxisType) in
            // Reset state
            self.mappingEngine.clearAxisToKeyConfigs()
            
            let negativeKey = KeyAction(keyCode: 0x01) // 'S' key
            let config = AxisToKeyConfig(
                positiveKey: nil,
                negativeKey: negativeKey,
                threshold: threshold
            )
            self.mappingEngine.setAxisToKeyConfig(config, for: axis)
            
            // Generate a value that exceeds the negative threshold
            let valueBelowNegativeThreshold = -threshold - 0.01
            let event = AxisEvent(axis: axis, normalizedValue: valueBelowNegativeThreshold)
            
            let actions = self.mappingEngine.handleAxisEvent(event)
            
            // Should contain a keyPress action for the negative key
            let hasKeyPress = actions.contains { action in
                if case .keyPress(let key) = action {
                    return key == negativeKey
                }
                return false
            }
            
            return hasKeyPress
        }
    }

    
    /// **Feature: ps5-gamepad-mapper, Property 4: Axis-to-Key Threshold Behavior**
    /// **Validates: Requirements 7.1, 7.2, 7.3**
    ///
    /// *For any* axis value that returns below the threshold after being above,
    /// the corresponding key SHALL be released.
    func testThresholdReturn_EmitsKeyRelease() {
        property("Axis returning below threshold emits key release") <- forAll(
            Self.thresholdGen,
            Self.stickAxisGen
        ) { (threshold: Double, axis: AxisType) in
            // Reset state
            self.mappingEngine.clearAxisToKeyConfigs()
            
            let positiveKey = KeyAction(keyCode: 0x00) // 'A' key
            let config = AxisToKeyConfig(
                positiveKey: positiveKey,
                negativeKey: nil,
                threshold: threshold
            )
            self.mappingEngine.setAxisToKeyConfig(config, for: axis)
            
            // First, exceed the threshold to press the key
            let valueAboveThreshold = threshold + 0.01
            let pressEvent = AxisEvent(axis: axis, normalizedValue: valueAboveThreshold)
            _ = self.mappingEngine.handleAxisEvent(pressEvent)
            
            // Now return below threshold
            let valueBelowThreshold = threshold - 0.01
            let releaseEvent = AxisEvent(axis: axis, normalizedValue: valueBelowThreshold)
            let actions = self.mappingEngine.handleAxisEvent(releaseEvent)
            
            // Should contain a keyRelease action for the positive key
            let hasKeyRelease = actions.contains { action in
                if case .keyRelease(let key) = action {
                    return key == positiveKey
                }
                return false
            }
            
            return hasKeyRelease
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 4: Axis-to-Key Threshold Behavior**
    /// **Validates: Requirements 7.1, 7.2, 7.3**
    ///
    /// *For any* axis value below threshold, no key press should occur
    /// (when starting from neutral state).
    func testBelowThreshold_NoKeyPress() {
        property("Axis value below threshold does not emit key press") <- forAll(
            Self.thresholdGen,
            Self.stickAxisGen
        ) { (threshold: Double, axis: AxisType) in
            // Reset state
            self.mappingEngine.clearAxisToKeyConfigs()
            
            let positiveKey = KeyAction(keyCode: 0x00)
            let negativeKey = KeyAction(keyCode: 0x01)
            let config = AxisToKeyConfig(
                positiveKey: positiveKey,
                negativeKey: negativeKey,
                threshold: threshold
            )
            self.mappingEngine.setAxisToKeyConfig(config, for: axis)
            
            // Generate a value that is below the threshold (in the deadzone)
            let valueBelowThreshold = threshold * 0.5
            let event = AxisEvent(axis: axis, normalizedValue: valueBelowThreshold)
            
            let actions = self.mappingEngine.handleAxisEvent(event)
            
            // Should not contain any keyPress actions
            let hasKeyPress = actions.contains { action in
                if case .keyPress = action {
                    return true
                }
                return false
            }
            
            return !hasKeyPress
        }
    }

    
    /// **Feature: ps5-gamepad-mapper, Property 4: Axis-to-Key Threshold Behavior**
    /// **Validates: Requirements 7.1, 7.2, 7.3**
    ///
    /// *For any* axis that is already pressed, staying above threshold
    /// should not emit duplicate key presses.
    func testStayingAboveThreshold_NoDuplicateKeyPress() {
        property("Staying above threshold does not emit duplicate key press") <- forAll(
            Self.thresholdGen,
            Self.stickAxisGen
        ) { (threshold: Double, axis: AxisType) in
            // Reset state
            self.mappingEngine.clearAxisToKeyConfigs()
            
            let positiveKey = KeyAction(keyCode: 0x00)
            let config = AxisToKeyConfig(
                positiveKey: positiveKey,
                negativeKey: nil,
                threshold: threshold
            )
            self.mappingEngine.setAxisToKeyConfig(config, for: axis)
            
            // First event above threshold - should press
            let value1 = threshold + 0.1
            let event1 = AxisEvent(axis: axis, normalizedValue: value1)
            let actions1 = self.mappingEngine.handleAxisEvent(event1)
            
            // Second event still above threshold - should NOT press again
            let value2 = threshold + 0.2
            let event2 = AxisEvent(axis: axis, normalizedValue: value2)
            let actions2 = self.mappingEngine.handleAxisEvent(event2)
            
            // First should have key press
            let firstHasPress = actions1.contains { action in
                if case .keyPress = action { return true }
                return false
            }
            
            // Second should NOT have key press
            let secondHasPress = actions2.contains { action in
                if case .keyPress = action { return true }
                return false
            }
            
            return firstHasPress && !secondHasPress
        }
    }
    
    // MARK: - Static Generators
    
    /// Generator for valid threshold values (0.1 to 0.9)
    private static var thresholdGen: Gen<Double> {
        Gen.fromElements(of: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9])
    }
    
    /// Generator for stick axes only (not triggers, since triggers don't have negative direction)
    private static var stickAxisGen: Gen<AxisType> {
        Gen.fromElements(of: [.leftStickX, .leftStickY, .rightStickX, .rightStickY])
    }
    
    /// Generator for trigger axes
    private static var triggerAxisGen: Gen<AxisType> {
        Gen.fromElements(of: [.l2Trigger, .r2Trigger])
    }
}
