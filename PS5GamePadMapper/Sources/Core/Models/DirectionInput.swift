import Foundation

/// Direction input source for stick direction mappings
/// Requirements: 2.1 - Direction as input source
/// Requirements: 2.5 - Threshold values from 0.1 to 0.9
public struct DirectionInput: Codable, Equatable, Hashable {
    public let stick: StickType
    public let direction: StickDirection
    public let threshold: Double
    
    /// Creates a new DirectionInput with threshold clamped to [0.1, 0.9]
    /// - Parameters:
    ///   - stick: Which stick (left or right)
    ///   - direction: The direction to map
    ///   - threshold: Activation threshold, clamped to [0.1, 0.9]
    public init(stick: StickType, direction: StickDirection, threshold: Double = 0.5) {
        self.stick = stick
        self.direction = direction
        self.threshold = max(0.1, min(0.9, threshold))
    }
}
