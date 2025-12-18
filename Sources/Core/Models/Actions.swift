import Foundation

/// Keyboard key action
public struct KeyAction: Codable, Equatable {
    public let keyCode: UInt16
    public let modifiers: KeyModifiers
    
    public init(keyCode: UInt16, modifiers: KeyModifiers = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// Mouse button action
public struct MouseButtonAction: Codable, Equatable {
    public let button: MouseButton
    
    public init(button: MouseButton) {
        self.button = button
    }
}

/// Mouse movement action
public struct MouseMoveAction: Codable, Equatable {
    public let sensitivity: Double
    public let deadzone: Double
    public let curve: ResponseCurve
    
    public init(sensitivity: Double = 1.0, deadzone: Double = 0.1, curve: ResponseCurve = .linear) {
        self.sensitivity = sensitivity
        self.deadzone = deadzone
        self.curve = curve
    }
}

/// Mouse scroll action
public struct MouseScrollAction: Codable, Equatable {
    public let direction: ScrollDirection
    public let amount: Double
    
    public init(direction: ScrollDirection, amount: Double = 1.0) {
        self.direction = direction
        self.amount = amount
    }
}

/// Trigger mode for mappings
/// Requirements: 4.5 - Support Press, Release, and Hold trigger types
public enum TriggerMode: Codable, Equatable {
    case press
    case release
    case hold(threshold: TimeInterval)
    case toggle
}

/// Input source for mappings
public enum InputSource: Codable, Equatable, Hashable {
    case button(ButtonType)
    case axis(AxisType)
    case direction(DirectionInput)
}

/// All possible mapping actions
public enum Action: Codable, Equatable {
    case keyPress(KeyAction)
    case keyRelease(KeyAction)
    case mouseButton(MouseButtonAction)
    case mouseMove(MouseMoveAction)
    case mouseScroll(MouseScrollAction)
    case macro(Macro)
    case script(Script)
}
