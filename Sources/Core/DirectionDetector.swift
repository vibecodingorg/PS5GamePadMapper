import Foundation

/// Direction detector for analog stick input
/// Converts raw X/Y stick coordinates into discrete direction events
/// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5
public final class DirectionDetector {
    
    // MARK: - Configuration
    
    /// Configuration for direction detection
    public struct Config: Equatable {
        /// Deadzone threshold - stick must exceed this to register any input
        public let deadzone: Double
        
        /// Direction activation threshold - magnitude must exceed this to trigger direction
        public let threshold: Double
        
        /// Half-width of cardinal direction zones in degrees (default 22.5°)
        /// Cardinal directions span ±cardinalAngle from their center
        public let cardinalAngle: Double
        
        /// Creates a new configuration with validated parameters
        /// - Parameters:
        ///   - deadzone: Deadzone threshold (default 0.1)
        ///   - threshold: Direction activation threshold, clamped to [0.1, 0.9] (default 0.5)
        ///   - cardinalAngle: Half-width of cardinal zones in degrees (default 22.5)
        public init(deadzone: Double = 0.1, threshold: Double = 0.5, cardinalAngle: Double = 22.5) {
            self.deadzone = max(0.0, deadzone)
            self.threshold = max(0.1, min(0.9, threshold))
            self.cardinalAngle = max(0.0, min(45.0, cardinalAngle))
        }
    }
    
    // MARK: - State
    
    /// Currently active directions per stick
    private var activeDirections: [StickType: Set<StickDirection>] = [
        .left: [],
        .right: []
    ]
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods

    
    /// Calculates the angle in degrees from stick coordinates
    /// Uses atan2 for accurate angle calculation, converts to 0-360 range
    /// Requirements: 6.1 - Use arctangent
    /// - Parameters:
    ///   - x: X coordinate (-1.0 to 1.0)
    ///   - y: Y coordinate (-1.0 to 1.0)
    /// - Returns: Angle in degrees (0-360), where 0 is right/east
    public func calculateAngle(x: Double, y: Double) -> Double {
        // Handle edge case of zero input
        guard x != 0 || y != 0 else { return 0 }
        
        // atan2 returns radians in range [-π, π]
        let radians = atan2(y, x)
        
        // Convert to degrees
        var degrees = radians * 180.0 / .pi
        
        // Normalize to 0-360 range
        if degrees < 0 {
            degrees += 360.0
        }
        
        return degrees
    }
    
    /// Calculates the magnitude of stick deflection
    /// - Parameters:
    ///   - x: X coordinate (-1.0 to 1.0)
    ///   - y: Y coordinate (-1.0 to 1.0)
    /// - Returns: Magnitude (0.0 to ~1.414 for corner positions)
    public func calculateMagnitude(x: Double, y: Double) -> Double {
        return sqrt(x * x + y * y)
    }
    
    /// Classifies an angle into one of 8 directions
    /// Requirements: 1.3, 1.4 - Cardinal and diagonal classification
    /// - Parameters:
    ///   - angle: Angle in degrees (0-360)
    ///   - cardinalAngle: Half-width of cardinal zones (default 22.5)
    /// - Returns: The classified direction
    public func classifyDirection(angle: Double, cardinalAngle: Double = 22.5) -> StickDirection {
        // Normalize angle to 0-360
        var normalizedAngle = angle.truncatingRemainder(dividingBy: 360.0)
        if normalizedAngle < 0 {
            normalizedAngle += 360.0
        }
        
        // Check each direction's zone
        // Cardinal directions: center ± cardinalAngle
        // Diagonal directions: fill the remaining 45° sectors
        
        // Right: 0° ± cardinalAngle (wraps around 360)
        if normalizedAngle <= cardinalAngle || normalizedAngle > 360.0 - cardinalAngle {
            return .right
        }
        
        // UpRight: 45° (between right and up zones)
        if normalizedAngle > cardinalAngle && normalizedAngle <= 90.0 - cardinalAngle {
            return .upRight
        }
        
        // Up: 90° ± cardinalAngle
        if normalizedAngle > 90.0 - cardinalAngle && normalizedAngle <= 90.0 + cardinalAngle {
            return .up
        }
        
        // UpLeft: 135° (between up and left zones)
        if normalizedAngle > 90.0 + cardinalAngle && normalizedAngle <= 180.0 - cardinalAngle {
            return .upLeft
        }
        
        // Left: 180° ± cardinalAngle
        if normalizedAngle > 180.0 - cardinalAngle && normalizedAngle <= 180.0 + cardinalAngle {
            return .left
        }
        
        // DownLeft: 225° (between left and down zones)
        if normalizedAngle > 180.0 + cardinalAngle && normalizedAngle <= 270.0 - cardinalAngle {
            return .downLeft
        }
        
        // Down: 270° ± cardinalAngle
        if normalizedAngle > 270.0 - cardinalAngle && normalizedAngle <= 270.0 + cardinalAngle {
            return .down
        }
        
        // DownRight: 315° (between down and right zones)
        return .downRight
    }

    
    /// Processes stick input and returns direction events
    /// Requirements: 1.2, 6.2, 6.3, 6.4, 6.5
    /// - Parameters:
    ///   - x: X coordinate (-1.0 to 1.0)
    ///   - y: Y coordinate (-1.0 to 1.0)
    ///   - stick: Which stick (left or right)
    ///   - config: Detection configuration
    /// - Returns: Array of direction events (releases before presses)
    public func processStickInput(x: Double, y: Double, stick: StickType, config: Config) -> [DirectionEvent] {
        var events: [DirectionEvent] = []
        
        let magnitude = calculateMagnitude(x: x, y: y)
        let angle = calculateAngle(x: x, y: y)
        
        // Get current active directions for this stick
        let previousDirections = activeDirections[stick] ?? []
        var newDirections: Set<StickDirection> = []
        
        // Only detect direction if magnitude exceeds threshold
        // Requirements: 6.2, 6.3 - Deadzone and threshold checks
        if magnitude > config.threshold {
            let direction = classifyDirection(angle: angle, cardinalAngle: config.cardinalAngle)
            newDirections.insert(direction)
        }
        
        // Determine which directions were released and which were pressed
        let releasedDirections = previousDirections.subtracting(newDirections)
        let pressedDirections = newDirections.subtracting(previousDirections)
        let heldDirections = previousDirections.intersection(newDirections)
        
        // Requirements: 6.4 - Emit release events before press events
        for direction in releasedDirections {
            events.append(DirectionEvent(
                stick: stick,
                direction: direction,
                state: .released,
                angle: angle,
                magnitude: magnitude
            ))
        }
        
        // Emit press events for newly activated directions
        for direction in pressedDirections {
            events.append(DirectionEvent(
                stick: stick,
                direction: direction,
                state: .pressed,
                angle: angle,
                magnitude: magnitude
            ))
        }
        
        // Requirements: 6.5 - No repeated press events when held
        // We don't emit held events here as they're typically not needed
        // The caller can track held state if needed
        _ = heldDirections
        
        // Update active directions
        activeDirections[stick] = newDirections
        
        return events
    }
    
    /// Resets all active directions
    /// Useful when controller disconnects or profile changes
    public func reset() {
        activeDirections[.left] = []
        activeDirections[.right] = []
    }
    
    /// Gets the currently active directions for a stick
    /// - Parameter stick: Which stick to query
    /// - Returns: Set of currently active directions
    public func getActiveDirections(for stick: StickType) -> Set<StickDirection> {
        return activeDirections[stick] ?? []
    }
}
