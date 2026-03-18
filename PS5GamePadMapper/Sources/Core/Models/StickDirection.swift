import Foundation

/// 摇杆方向枚举 - 8 distinct directions for analog stick input
/// Requirements: 1.1 - 8 distinct directions
public enum StickDirection: String, Codable, CaseIterable, Equatable, Hashable {
    case up = "Up"
    case down = "Down"
    case left = "Left"
    case right = "Right"
    case upLeft = "UpLeft"
    case upRight = "UpRight"
    case downLeft = "DownLeft"
    case downRight = "DownRight"
    
    /// Whether this is a cardinal direction (Up, Down, Left, Right)
    public var isCardinal: Bool {
        switch self {
        case .up, .down, .left, .right:
            return true
        case .upLeft, .upRight, .downLeft, .downRight:
            return false
        }
    }
    
    /// Whether this is a diagonal direction (UpLeft, UpRight, DownLeft, DownRight)
    public var isDiagonal: Bool {
        return !isCardinal
    }
    
    /// For diagonal directions, returns the two adjacent cardinal directions
    /// For cardinal directions, returns an empty array
    public var adjacentCardinals: [StickDirection] {
        switch self {
        case .upLeft:
            return [.up, .left]
        case .upRight:
            return [.up, .right]
        case .downLeft:
            return [.down, .left]
        case .downRight:
            return [.down, .right]
        case .up, .down, .left, .right:
            return []
        }
    }
    
    /// The center angle in degrees for this direction (0-360, where 0 is right/east)
    /// Uses standard mathematical convention: counter-clockwise from positive X axis
    public var centerAngle: Double {
        switch self {
        case .right:
            return 0
        case .upRight:
            return 45
        case .up:
            return 90
        case .upLeft:
            return 135
        case .left:
            return 180
        case .downLeft:
            return 225
        case .down:
            return 270
        case .downRight:
            return 315
        }
    }
    
    /// Short arrow symbol label for the direction
    /// Requirements: 6.2 - Show direction icon (e.g., "↑", "↗")
    public var shortLabel: String {
        switch self {
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        case .upLeft: return "↖"
        case .upRight: return "↗"
        case .downLeft: return "↙"
        case .downRight: return "↘"
        }
    }
    
    /// Localized display name for the direction
    /// Requirements: 6.2 - Show direction name (e.g., "上", "右上")
    public var localizedName: String {
        switch self {
        case .up: return "上"
        case .down: return "下"
        case .left: return "左"
        case .right: return "右"
        case .upLeft: return "左上"
        case .upRight: return "右上"
        case .downLeft: return "左下"
        case .downRight: return "右下"
        }
    }
}
