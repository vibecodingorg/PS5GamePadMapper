import Foundation

/// All DualSense controller button types
/// Requirements: 2.4 - Support all DualSense buttons
public enum ButtonType: String, Codable, CaseIterable, Equatable, Hashable {
    case cross = "X"
    case circle = "O"
    case square = "Square"
    case triangle = "Triangle"
    case l1 = "L1"
    case r1 = "R1"
    case l2 = "L2"
    case r2 = "R2"
    case l3 = "L3"
    case r3 = "R3"
    case dpadUp = "DPad_Up"
    case dpadDown = "DPad_Down"
    case dpadLeft = "DPad_Left"
    case dpadRight = "DPad_Right"
    case share = "Share"
    case options = "Options"
    case ps = "PS"
    case touchpad = "Touchpad"
}

/// Button press state
public enum ButtonState: Equatable {
    case pressed
    case released
    case held(duration: TimeInterval)
}
