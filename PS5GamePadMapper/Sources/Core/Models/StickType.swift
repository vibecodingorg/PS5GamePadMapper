import Foundation

/// Identifies which analog stick on the controller
/// Requirements: 1.1 - Support left and right stick identification
public enum StickType: String, Codable, CaseIterable, Equatable, Hashable {
    case left = "LeftStick"
    case right = "RightStick"
}
