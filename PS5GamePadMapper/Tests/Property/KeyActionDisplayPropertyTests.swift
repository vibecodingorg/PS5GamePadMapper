import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Key Action Display Formatting
/// **Feature: stick-interaction-enhancement, Property 10: Key Action Display Formatting**
final class KeyActionDisplayPropertyTests: XCTestCase {
    
    // MARK: - Property 10: Key Action Display Formatting
    
    /// **Feature: stick-interaction-enhancement, Property 10: Key Action Display Formatting**
    /// **Validates: Requirements 6.4**
    ///
    /// *For any* KeyAction with keyCode and modifiers, the displayed string should include
    /// the key name and all modifier symbols in the correct format (e.g., "⌘+Shift+A").
    func testKeyActionDisplayFormatting() {
        // Test that key actions without modifiers show just the key name
        property("Key actions without modifiers show just key name") <- forAll { (keyCode: UInt16) in
            let keyAction = KeyAction(keyCode: keyCode, modifiers: [])
            let action = Action.keyPress(keyAction)
            let description = action.displayDescription
            
            // Should not contain any modifier symbols
            return !description.contains("⌘") &&
                   !description.contains("⌃") &&
                   !description.contains("⌥") &&
                   !description.contains("⇧") &&
                   !description.contains("+")
        }
        
        // Test that key actions with command modifier include ⌘
        property("Key actions with command modifier include ⌘") <- forAll { (keyCode: UInt16) in
            let keyAction = KeyAction(keyCode: keyCode, modifiers: [.command])
            let action = Action.keyPress(keyAction)
            let description = action.displayDescription
            
            return description.contains("⌘")
        }
        
        // Test that key actions with shift modifier include ⇧
        property("Key actions with shift modifier include ⇧") <- forAll { (keyCode: UInt16) in
            let keyAction = KeyAction(keyCode: keyCode, modifiers: [.shift])
            let action = Action.keyPress(keyAction)
            let description = action.displayDescription
            
            return description.contains("⇧")
        }
        
        // Test that key actions with control modifier include ⌃
        property("Key actions with control modifier include ⌃") <- forAll { (keyCode: UInt16) in
            let keyAction = KeyAction(keyCode: keyCode, modifiers: [.control])
            let action = Action.keyPress(keyAction)
            let description = action.displayDescription
            
            return description.contains("⌃")
        }
        
        // Test that key actions with option modifier include ⌥
        property("Key actions with option modifier include ⌥") <- forAll { (keyCode: UInt16) in
            let keyAction = KeyAction(keyCode: keyCode, modifiers: [.option])
            let action = Action.keyPress(keyAction)
            let description = action.displayDescription
            
            return description.contains("⌥")
        }
        
        // Test that key actions with multiple modifiers include all modifier symbols
        property("Key actions with multiple modifiers include all symbols") <- forAll { (keyCode: UInt16) in
            let keyAction = KeyAction(keyCode: keyCode, modifiers: [.command, .shift])
            let action = Action.keyPress(keyAction)
            let description = action.displayDescription
            
            return description.contains("⌘") && description.contains("⇧")
        }
    }
    
    /// Test that modifier display string is correctly formatted
    func testModifierDisplayString() {
        // Test empty modifiers
        property("Empty modifiers produce empty string") <- forAll { (_: Int) in
            let modifiers: KeyModifiers = []
            return modifiers.displayString.isEmpty
        }
        
        // Test single modifiers
        property("Single command modifier produces ⌘") <- forAll { (_: Int) in
            let modifiers: KeyModifiers = [.command]
            return modifiers.displayString == "⌘"
        }
        
        property("Single shift modifier produces ⇧") <- forAll { (_: Int) in
            let modifiers: KeyModifiers = [.shift]
            return modifiers.displayString == "⇧"
        }
        
        // Test multiple modifiers are joined with +
        property("Multiple modifiers are joined with +") <- forAll { (_: Int) in
            let modifiers: KeyModifiers = [.command, .shift]
            let displayString = modifiers.displayString
            return displayString.contains("+") && displayString.contains("⌘") && displayString.contains("⇧")
        }
        
        // Test all modifiers
        property("All modifiers produce correct string") <- forAll { (_: Int) in
            let modifiers: KeyModifiers = [.command, .control, .option, .shift]
            let displayString = modifiers.displayString
            return displayString.contains("⌘") &&
                   displayString.contains("⌃") &&
                   displayString.contains("⌥") &&
                   displayString.contains("⇧")
        }
    }
    
    /// Test that key code to name conversion works correctly
    func testKeyCodeToName() {
        // Test common key codes
        property("Common key codes have correct names") <- forAll { (_: Int) in
            // Test a few known key codes
            let testCases: [(UInt16, String)] = [
                (0, "A"), (1, "S"), (2, "D"), (13, "W"),
                (49, "Space"), (36, "Return"), (53, "Escape")
            ]
            
            return testCases.allSatisfy { keyCode, expectedName in
                Action.keyCodeToName(keyCode) == expectedName
            }
        }
        
        // Test unknown key codes produce "Key X" format
        property("Unknown key codes produce Key X format") <- forAll { (keyCode: UInt16) in
            // Use a key code that's definitely not in the mapping
            let unknownKeyCode: UInt16 = 200
            let name = Action.keyCodeToName(unknownKeyCode)
            return name == "Key 200"
        }
    }
    
    /// Test that display description is never empty
    func testDisplayDescriptionNeverEmpty() {
        property("KeyPress display description is never empty") <- forAll { (keyAction: KeyAction) in
            let action = Action.keyPress(keyAction)
            return !action.displayDescription.isEmpty
        }
        
        property("KeyRelease display description is never empty") <- forAll { (keyAction: KeyAction) in
            let action = Action.keyRelease(keyAction)
            return !action.displayDescription.isEmpty
        }
    }
}
