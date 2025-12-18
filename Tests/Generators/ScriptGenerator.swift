import Foundation
import SwiftCheck
@testable import PS5GamePadMapperCore

// MARK: - Key Name Generator

/// Generator for valid key names that the script API supports
struct KeyNameGenerator: Arbitrary {
    let value: String
    
    static var arbitrary: Gen<KeyNameGenerator> {
        let letters = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
                       "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
        let numbers = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        let special = ["space", "return", "enter", "tab", "escape", "esc", "delete", "backspace"]
        let arrows = ["up", "down", "left", "right"]
        let functionKeys = ["f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12"]
        
        let allKeys = letters + numbers + special + arrows + functionKeys
        
        return Gen<String>.fromElements(of: allKeys).map { KeyNameGenerator(value: $0) }
    }
}

// MARK: - Mouse Button Name Generator

/// Generator for valid mouse button names
struct MouseButtonNameGenerator: Arbitrary {
    let value: String
    
    static var arbitrary: Gen<MouseButtonNameGenerator> {
        let buttons = ["left", "right", "middle", "Left", "Right", "Middle"]
        return Gen<String>.fromElements(of: buttons).map { MouseButtonNameGenerator(value: $0) }
    }
}

// MARK: - Controller Button Name Generator

/// Generator for valid controller button names
struct ControllerButtonNameGenerator: Arbitrary {
    let value: String
    
    static var arbitrary: Gen<ControllerButtonNameGenerator> {
        let buttons = ButtonType.allCases.map { $0.rawValue }
        return Gen<String>.fromElements(of: buttons).map { ControllerButtonNameGenerator(value: $0) }
    }
}


// MARK: - Duration Generator

/// Generator for valid durations (1-1000ms for testing)
struct DurationGenerator: Arbitrary {
    let value: Int
    
    static var arbitrary: Gen<DurationGenerator> {
        return Gen<Int>.choose((1, 1000)).map { DurationGenerator(value: $0) }
    }
}

// MARK: - Mouse Delta Generator

/// Generator for mouse movement deltas (-500 to 500)
struct MouseDeltaGenerator: Arbitrary {
    let dx: Int
    let dy: Int
    
    static var arbitrary: Gen<MouseDeltaGenerator> {
        return Gen<(Int, Int)>.zip(
            Gen<Int>.choose((-500, 500)),
            Gen<Int>.choose((-500, 500))
        ).map { MouseDeltaGenerator(dx: $0.0, dy: $0.1) }
    }
}

// MARK: - Script Command Generators

/// Generator for pressKey script commands
struct PressKeyCommandGenerator: Arbitrary {
    let key: String
    
    static var arbitrary: Gen<PressKeyCommandGenerator> {
        return KeyNameGenerator.arbitrary.map { PressKeyCommandGenerator(key: $0.value) }
    }
    
    var scriptLine: String {
        return "pressKey(\(key))"
    }
}

/// Generator for releaseKey script commands
struct ReleaseKeyCommandGenerator: Arbitrary {
    let key: String
    
    static var arbitrary: Gen<ReleaseKeyCommandGenerator> {
        return KeyNameGenerator.arbitrary.map { ReleaseKeyCommandGenerator(key: $0.value) }
    }
    
    var scriptLine: String {
        return "releaseKey(\(key))"
    }
}

/// Generator for tapKey script commands
struct TapKeyCommandGenerator: Arbitrary {
    let key: String
    let duration: Int
    
    static var arbitrary: Gen<TapKeyCommandGenerator> {
        return Gen<(KeyNameGenerator, DurationGenerator)>.zip(
            KeyNameGenerator.arbitrary,
            DurationGenerator.arbitrary
        ).map { TapKeyCommandGenerator(key: $0.0.value, duration: $0.1.value) }
    }
    
    var scriptLine: String {
        return "tapKey(\(key), \(duration))"
    }
}

/// Generator for mouseClick script commands
struct MouseClickCommandGenerator: Arbitrary {
    let button: String
    
    static var arbitrary: Gen<MouseClickCommandGenerator> {
        return MouseButtonNameGenerator.arbitrary.map { MouseClickCommandGenerator(button: $0.value) }
    }
    
    var scriptLine: String {
        return "mouseClick(\(button))"
    }
}

/// Generator for mouseMove script commands
struct MouseMoveCommandGenerator: Arbitrary {
    let dx: Int
    let dy: Int
    
    static var arbitrary: Gen<MouseMoveCommandGenerator> {
        return MouseDeltaGenerator.arbitrary.map { MouseMoveCommandGenerator(dx: $0.dx, dy: $0.dy) }
    }
    
    var scriptLine: String {
        return "mouseMove(\(dx), \(dy))"
    }
}
