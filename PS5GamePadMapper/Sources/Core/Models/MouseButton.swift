import Foundation

/// Mouse button types
/// Requirements: 5.2 - Support left, right, and middle mouse buttons
public enum MouseButton: String, Codable, Equatable {
    case left = "Left"
    case right = "Right"
    case middle = "Middle"
}

/// Scroll direction types
/// Requirements: 5.4 - Support up, down, left, and right scroll directions
public enum ScrollDirection: String, Codable, Equatable {
    case up = "Up"
    case down = "Down"
    case left = "Left"
    case right = "Right"
}
