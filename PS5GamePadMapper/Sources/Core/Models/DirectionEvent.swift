import Foundation

/// Direction state for direction events
/// Requirements: 1.5, 2.4 - Direction press/release events
public enum DirectionState: Equatable, Hashable {
    case pressed
    case released
    case held
}

/// Direction event representing a stick direction change
/// Requirements: 1.5, 2.4 - Direction press/release events
public struct DirectionEvent: Equatable {
    /// Which stick generated this event
    public let stick: StickType
    
    /// The direction that changed
    public let direction: StickDirection
    
    /// The state of the direction (pressed, released, held)
    public let state: DirectionState
    
    /// Current angle in degrees (0-360)
    public let angle: Double
    
    /// Current magnitude (0.0-1.0)
    public let magnitude: Double
    
    /// Creates a new DirectionEvent
    /// - Parameters:
    ///   - stick: Which stick (left or right)
    ///   - direction: The direction that changed
    ///   - state: The state of the direction
    ///   - angle: Current angle in degrees
    ///   - magnitude: Current magnitude (0.0-1.0)
    public init(stick: StickType, direction: StickDirection, state: DirectionState,
                angle: Double, magnitude: Double) {
        self.stick = stick
        self.direction = direction
        self.state = state
        self.angle = angle
        self.magnitude = magnitude
    }
}
