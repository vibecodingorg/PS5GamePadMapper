import Foundation

/// All DualSense controller axis types
/// Requirements: 3.3 - Support left stick, right stick, L2/R2 triggers
public enum AxisType: String, Codable, CaseIterable, Equatable, Hashable {
    case leftStickX = "LStick_X"
    case leftStickY = "LStick_Y"
    case rightStickX = "RStick_X"
    case rightStickY = "RStick_Y"
    case l2Trigger = "L2_Trigger"
    case r2Trigger = "R2_Trigger"
    
    /// Whether this axis is a trigger (0.0 to 1.0) or stick (-1.0 to 1.0)
    public var isTrigger: Bool {
        switch self {
        case .l2Trigger, .r2Trigger:
            return true
        case .leftStickX, .leftStickY, .rightStickX, .rightStickY:
            return false
        }
    }
}
