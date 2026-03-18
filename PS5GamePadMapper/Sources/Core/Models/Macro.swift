import Foundation

/// Macro type definitions
/// Requirements: 8.2, 8.3, 9.1, 10.1, 4.1 (whileCondition)
public enum MacroType: Codable, Equatable, Hashable {
    case sequence
    case loop(interval: Int, maxCount: Int)  // maxCount 0 = infinite
    case toggle
    case whileCondition(condition: String)   // Requirements: 4.1 - condition expression as string
}

/// Individual macro step
/// Requirements: 8.2 - Support key press, key release, mouse click, mouse move, delay
public enum MacroStep: Codable, Equatable {
    case keyDown(keyCode: UInt16)
    case keyUp(keyCode: UInt16)
    case mouseClick(button: MouseButton)
    case mouseMove(dx: Int, dy: Int)
    case delay(milliseconds: Int)
}

/// A macro definition containing a sequence of steps
/// Requirements: 8.5, 8.6 - Serializable to/from JSON
public struct Macro: Codable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let steps: [MacroStep]
    public let type: MacroType
    
    public init(id: UUID = UUID(), name: String, steps: [MacroStep], type: MacroType = .sequence) {
        self.id = id
        self.name = name
        self.steps = steps
        self.type = type
    }
}
