import Foundation
import SwiftCheck
@testable import PS5GamePadMapperCore

// MARK: - Key Code Generator

/// Wrapper for generating valid key codes
struct ValidKeyCode: Arbitrary {
    let keyCode: UInt16
    
    static var arbitrary: Gen<ValidKeyCode> {
        // Generate key codes in the valid range (0-127 covers most keys)
        Gen.fromElements(in: 0...127).map { ValidKeyCode(keyCode: UInt16($0)) }
    }
}

// MARK: - Key Action Input for Testing

/// Represents a key action with modifiers for property testing
struct KeyActionInput: Arbitrary {
    let keyCode: UInt16
    let modifiers: KeyModifiers
    
    static var arbitrary: Gen<KeyActionInput> {
        Gen.compose { c in
            KeyActionInput(
                keyCode: c.generate(using: ValidKeyCode.arbitrary).keyCode,
                modifiers: c.generate()
            )
        }
    }
}
