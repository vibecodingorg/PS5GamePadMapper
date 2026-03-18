import Foundation

/// Raw button input from HID
public struct RawButtonInput: Equatable {
    public let button: ButtonType
    public let isPressed: Bool
    public let timestamp: UInt64
    
    public init(button: ButtonType, isPressed: Bool, timestamp: UInt64) {
        self.button = button
        self.isPressed = isPressed
        self.timestamp = timestamp
    }
}

/// Raw axis input from HID
public struct RawAxisInput: Equatable {
    public let axis: AxisType
    public let rawValue: Int16  // -32768 to 32767 for sticks, 0-255 for triggers
    public let timestamp: UInt64
    
    public init(axis: AxisType, rawValue: Int16, timestamp: UInt64) {
        self.axis = axis
        self.rawValue = rawValue
        self.timestamp = timestamp
    }
}

/// Processed button event
public struct ButtonEvent: Equatable {
    public let button: ButtonType
    public let state: ButtonState
    public let holdDuration: TimeInterval?
    
    public init(button: ButtonType, state: ButtonState, holdDuration: TimeInterval? = nil) {
        self.button = button
        self.state = state
        self.holdDuration = holdDuration
    }
}

/// Processed axis event with normalized value
public struct AxisEvent: Equatable {
    public let axis: AxisType
    public let normalizedValue: Double  // -1.0 to 1.0 or 0.0 to 1.0
    
    public init(axis: AxisType, normalizedValue: Double) {
        self.axis = axis
        self.normalizedValue = normalizedValue
    }
}
