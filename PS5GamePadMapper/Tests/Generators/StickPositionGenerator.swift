import Foundation
import SwiftCheck
@testable import PS5GamePadMapperCore

// MARK: - StickPosition Wrapper

/// Represents a stick position with x, y coordinates in [-1, 1] range
/// Requirements: 6.1 - Stick position for direction calculation
public struct StickPosition: Equatable {
    public let x: Double
    public let y: Double
    
    public init(x: Double, y: Double) {
        self.x = max(-1.0, min(1.0, x))
        self.y = max(-1.0, min(1.0, y))
    }
    
    /// Calculate the magnitude of this position
    public var magnitude: Double {
        sqrt(x * x + y * y)
    }
    
    /// Calculate the angle in degrees (0-360, where 0 is right/east)
    public var angle: Double {
        var degrees = atan2(y, x) * 180.0 / .pi
        if degrees < 0 {
            degrees += 360.0
        }
        return degrees
    }
    
    /// Whether this position is in the deadzone (magnitude < threshold)
    public func isInDeadzone(threshold: Double) -> Bool {
        magnitude < threshold
    }
}

// MARK: - StickPosition Generator

extension StickPosition: Arbitrary {
    public static var arbitrary: Gen<StickPosition> {
        Gen.one(of: [
            // Random positions in full range
            randomPositionGenerator,
            // Edge cases: deadzone boundary positions
            deadzoneEdgeCaseGenerator,
            // Edge cases: threshold boundary positions
            thresholdEdgeCaseGenerator,
            // Edge cases: cardinal direction positions
            cardinalPositionGenerator,
            // Edge cases: diagonal direction positions
            diagonalPositionGenerator,
            // Edge cases: extreme positions
            extremePositionGenerator
        ])
    }
    
    /// Generator for random positions in [-1, 1] range
    public static var randomPositionGenerator: Gen<StickPosition> {
        Gen.zip(
            Gen<Double>.fromElements(in: -1.0...1.0),
            Gen<Double>.fromElements(in: -1.0...1.0)
        ).map { StickPosition(x: $0.0, y: $0.1) }
    }
    
    /// Generator for positions near deadzone boundary (magnitude ~0.1)
    public static var deadzoneEdgeCaseGenerator: Gen<StickPosition> {
        Gen.fromElements(of: [0.05, 0.09, 0.1, 0.11, 0.15]).flatMap { magnitude in
            Gen<Double>.fromElements(in: 0.0...360.0).map { angleDegrees in
                let angleRadians = angleDegrees * .pi / 180.0
                return StickPosition(
                    x: magnitude * cos(angleRadians),
                    y: magnitude * sin(angleRadians)
                )
            }
        }
    }
    
    /// Generator for positions near common threshold boundaries (0.3, 0.5, 0.7)
    public static var thresholdEdgeCaseGenerator: Gen<StickPosition> {
        Gen.zip(
            Gen.fromElements(of: [0.29, 0.3, 0.31, 0.49, 0.5, 0.51, 0.69, 0.7, 0.71]),
            Gen<Double>.fromElements(in: 0.0...360.0)
        ).map { (magnitude, angleDegrees) in
            let angleRadians = angleDegrees * .pi / 180.0
            return StickPosition(
                x: magnitude * cos(angleRadians),
                y: magnitude * sin(angleRadians)
            )
        }
    }
    
    /// Generator for cardinal direction positions (up, down, left, right)
    public static var cardinalPositionGenerator: Gen<StickPosition> {
        Gen.zip(
            Gen.fromElements(of: [0.5, 0.7, 1.0]),
            Gen.fromElements(of: [0.0, 90.0, 180.0, 270.0]) // Right, Up, Left, Down
        ).map { (magnitude, angleDegrees) in
            let angleRadians = angleDegrees * .pi / 180.0
            return StickPosition(
                x: magnitude * cos(angleRadians),
                y: magnitude * sin(angleRadians)
            )
        }
    }
    
    /// Generator for diagonal direction positions
    public static var diagonalPositionGenerator: Gen<StickPosition> {
        Gen.zip(
            Gen.fromElements(of: [0.5, 0.7, 1.0]),
            Gen.fromElements(of: [45.0, 135.0, 225.0, 315.0]) // UpRight, UpLeft, DownLeft, DownRight
        ).map { (magnitude, angleDegrees) in
            let angleRadians = angleDegrees * .pi / 180.0
            return StickPosition(
                x: magnitude * cos(angleRadians),
                y: magnitude * sin(angleRadians)
            )
        }
    }
    
    /// Generator for extreme positions (corners and edges)
    public static var extremePositionGenerator: Gen<StickPosition> {
        Gen.fromElements(of: [
            StickPosition(x: 0.0, y: 0.0),   // Center
            StickPosition(x: 1.0, y: 0.0),   // Right edge
            StickPosition(x: -1.0, y: 0.0),  // Left edge
            StickPosition(x: 0.0, y: 1.0),   // Top edge
            StickPosition(x: 0.0, y: -1.0),  // Bottom edge
            StickPosition(x: 1.0, y: 1.0),   // Top-right corner (will be clamped by magnitude)
            StickPosition(x: -1.0, y: 1.0),  // Top-left corner
            StickPosition(x: -1.0, y: -1.0), // Bottom-left corner
            StickPosition(x: 1.0, y: -1.0)   // Bottom-right corner
        ])
    }
}

// MARK: - Specialized Generators

/// Generator for positions guaranteed to be below a given threshold
public struct BelowThresholdPosition: Arbitrary {
    public let position: StickPosition
    public let threshold: Double
    
    public static var arbitrary: Gen<BelowThresholdPosition> {
        Gen.fromElements(of: [0.3, 0.5, 0.7]).flatMap { threshold in
            let maxMagnitude = threshold * 0.8 // 80% of threshold to ensure below
            return Gen.zip(
                Gen<Double>.fromElements(in: 0.0...maxMagnitude),
                Gen<Double>.fromElements(in: 0.0...360.0)
            ).map { (magnitude, angleDegrees) in
                let angleRadians = angleDegrees * .pi / 180.0
                let pos = StickPosition(
                    x: magnitude * cos(angleRadians),
                    y: magnitude * sin(angleRadians)
                )
                return BelowThresholdPosition(position: pos, threshold: threshold)
            }
        }
    }
}

/// Generator for positions guaranteed to be above a given threshold
public struct AboveThresholdPosition: Arbitrary {
    public let position: StickPosition
    public let threshold: Double
    
    public static var arbitrary: Gen<AboveThresholdPosition> {
        Gen.fromElements(of: [0.1, 0.3, 0.5]).flatMap { threshold in
            let minMagnitude = threshold + 0.1 // Ensure above threshold
            return Gen.zip(
                Gen<Double>.fromElements(in: minMagnitude...1.0),
                Gen<Double>.fromElements(in: 0.0...360.0)
            ).map { (magnitude, angleDegrees) in
                let angleRadians = angleDegrees * .pi / 180.0
                let pos = StickPosition(
                    x: magnitude * cos(angleRadians),
                    y: magnitude * sin(angleRadians)
                )
                return AboveThresholdPosition(position: pos, threshold: threshold)
            }
        }
    }
}

/// Generator for a sequence of stick positions (for testing state transitions)
public struct StickPositionSequence: Arbitrary {
    public let positions: [StickPosition]
    
    public static var arbitrary: Gen<StickPositionSequence> {
        Gen.compose { c in
            let count = c.generate(using: Gen.fromElements(in: 2...5))
            var positions: [StickPosition] = []
            for _ in 0..<count {
                positions.append(c.generate())
            }
            return StickPositionSequence(positions: positions)
        }
    }
}
