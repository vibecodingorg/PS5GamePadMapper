import XCTest
@testable import PS5GamePadMapperCore

final class CoreModelsTests: XCTestCase {
    
    // MARK: - ButtonType Tests
    
    func testButtonTypeAllCases() {
        // Verify all DualSense buttons are defined
        XCTAssertEqual(ButtonType.allCases.count, 18)
        XCTAssertTrue(ButtonType.allCases.contains(.cross))
        XCTAssertTrue(ButtonType.allCases.contains(.circle))
        XCTAssertTrue(ButtonType.allCases.contains(.square))
        XCTAssertTrue(ButtonType.allCases.contains(.triangle))
        XCTAssertTrue(ButtonType.allCases.contains(.l1))
        XCTAssertTrue(ButtonType.allCases.contains(.r1))
        XCTAssertTrue(ButtonType.allCases.contains(.l2))
        XCTAssertTrue(ButtonType.allCases.contains(.r2))
        XCTAssertTrue(ButtonType.allCases.contains(.l3))
        XCTAssertTrue(ButtonType.allCases.contains(.r3))
        XCTAssertTrue(ButtonType.allCases.contains(.dpadUp))
        XCTAssertTrue(ButtonType.allCases.contains(.dpadDown))
        XCTAssertTrue(ButtonType.allCases.contains(.dpadLeft))
        XCTAssertTrue(ButtonType.allCases.contains(.dpadRight))
        XCTAssertTrue(ButtonType.allCases.contains(.share))
        XCTAssertTrue(ButtonType.allCases.contains(.options))
        XCTAssertTrue(ButtonType.allCases.contains(.ps))
        XCTAssertTrue(ButtonType.allCases.contains(.touchpad))
    }
    
    func testButtonTypeCodable() throws {
        let button = ButtonType.cross
        let encoded = try JSONEncoder().encode(button)
        let decoded = try JSONDecoder().decode(ButtonType.self, from: encoded)
        XCTAssertEqual(button, decoded)
    }
    
    // MARK: - AxisType Tests
    
    func testAxisTypeAllCases() {
        XCTAssertEqual(AxisType.allCases.count, 6)
    }
    
    func testAxisTypeIsTrigger() {
        XCTAssertTrue(AxisType.l2Trigger.isTrigger)
        XCTAssertTrue(AxisType.r2Trigger.isTrigger)
        XCTAssertFalse(AxisType.leftStickX.isTrigger)
        XCTAssertFalse(AxisType.leftStickY.isTrigger)
        XCTAssertFalse(AxisType.rightStickX.isTrigger)
        XCTAssertFalse(AxisType.rightStickY.isTrigger)
    }
    
    // MARK: - KeyModifiers Tests
    
    func testKeyModifiersOptionSet() {
        var modifiers: KeyModifiers = []
        XCTAssertTrue(modifiers.isEmpty)
        
        modifiers.insert(.command)
        XCTAssertTrue(modifiers.contains(.command))
        XCTAssertFalse(modifiers.contains(.control))
        
        modifiers.insert(.shift)
        XCTAssertTrue(modifiers.contains(.command))
        XCTAssertTrue(modifiers.contains(.shift))
    }
    
    func testKeyModifiersOrderedModifiers() {
        let modifiers: KeyModifiers = [.shift, .command, .option]
        let ordered = modifiers.orderedModifiers
        
        // Should be in order: command, control, option, shift
        XCTAssertEqual(ordered.count, 3)
        XCTAssertEqual(ordered[0], .command)
        XCTAssertEqual(ordered[1], .option)
        XCTAssertEqual(ordered[2], .shift)
    }
    
    // MARK: - AxisConfig Tests
    
    func testAxisConfigValidation() {
        let validConfig = AxisConfig(deadzone: 0.1, sensitivity: 1.0, curve: .linear)
        XCTAssertNil(validConfig.validate())
        
        let invalidDeadzone = AxisConfig(deadzone: 0.6, sensitivity: 1.0, curve: .linear)
        XCTAssertNotNil(invalidDeadzone.validate())
        
        let invalidSensitivity = AxisConfig(deadzone: 0.1, sensitivity: 15.0, curve: .linear)
        XCTAssertNotNil(invalidSensitivity.validate())
    }
    
    // MARK: - ConnectionType Tests
    
    func testConnectionTypeCodable() throws {
        let usb = ConnectionType.usb
        let encoded = try JSONEncoder().encode(usb)
        let decoded = try JSONDecoder().decode(ConnectionType.self, from: encoded)
        XCTAssertEqual(usb, decoded)
    }
}
