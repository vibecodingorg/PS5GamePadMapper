import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Angle to Direction Classification
/// **Feature: stick-direction-mapping, Property 2: Angle to Direction Classification**
final class AngleToDirectionClassificationPropertyTests: XCTestCase {
    
    private var detector: DirectionDetector!
    
    override func setUp() {
        super.setUp()
        detector = DirectionDetector()
    }
    
    override func tearDown() {
        detector = nil
        super.tearDown()
    }
    
    // MARK: - Property 2: Angle to Direction Classification
    
    /// **Feature: stick-direction-mapping, Property 2: Angle to Direction Classification**
    /// **Validates: Requirements 1.3, 1.4**
    ///
    /// *For any* angle in degrees (0-360), the direction classifier should return the correct
    /// StickDirection based on the angle zones: cardinal directions within ±22.5° of their
    /// center angles (0°, 90°, 180°, 270°), and diagonal directions for the remaining 45° sectors.
    func testAngleToDirectionClassification() {
        let cardinalAngle = 22.5
        
        property("Angles classify to correct directions based on zones") <- forAll(
            Gen<Double>.fromElements(in: 0.0...360.0)
        ) { (angle: Double) in
            let direction = self.detector.classifyDirection(angle: angle, cardinalAngle: cardinalAngle)
            
            // Normalize angle to 0-360
            var normalizedAngle = angle.truncatingRemainder(dividingBy: 360.0)
            if normalizedAngle < 0 {
                normalizedAngle += 360.0
            }
            
            // Determine expected direction based on angle zones
            let expectedDirection: StickDirection
            
            // Right: 0° ± 22.5° (wraps around 360)
            if normalizedAngle <= cardinalAngle || normalizedAngle > 360.0 - cardinalAngle {
                expectedDirection = .right
            }
            // UpRight: 22.5° to 67.5°
            else if normalizedAngle > cardinalAngle && normalizedAngle <= 90.0 - cardinalAngle {
                expectedDirection = .upRight
            }
            // Up: 67.5° to 112.5°
            else if normalizedAngle > 90.0 - cardinalAngle && normalizedAngle <= 90.0 + cardinalAngle {
                expectedDirection = .up
            }
            // UpLeft: 112.5° to 157.5°
            else if normalizedAngle > 90.0 + cardinalAngle && normalizedAngle <= 180.0 - cardinalAngle {
                expectedDirection = .upLeft
            }
            // Left: 157.5° to 202.5°
            else if normalizedAngle > 180.0 - cardinalAngle && normalizedAngle <= 180.0 + cardinalAngle {
                expectedDirection = .left
            }
            // DownLeft: 202.5° to 247.5°
            else if normalizedAngle > 180.0 + cardinalAngle && normalizedAngle <= 270.0 - cardinalAngle {
                expectedDirection = .downLeft
            }
            // Down: 247.5° to 292.5°
            else if normalizedAngle > 270.0 - cardinalAngle && normalizedAngle <= 270.0 + cardinalAngle {
                expectedDirection = .down
            }
            // DownRight: 292.5° to 337.5°
            else {
                expectedDirection = .downRight
            }
            
            return direction == expectedDirection
        }
    }
    
    /// Test that cardinal directions are classified correctly at their center angles
    func testCardinalDirectionsAtCenterAngles() {
        let cardinalCases: [(StickDirection, Double)] = [
            (.right, 0.0),
            (.up, 90.0),
            (.left, 180.0),
            (.down, 270.0)
        ]
        
        for (expected, angle) in cardinalCases {
            let direction = detector.classifyDirection(angle: angle, cardinalAngle: 22.5)
            XCTAssertEqual(direction, expected, "Angle \(angle) should classify as \(expected)")
            XCTAssertTrue(direction.isCardinal, "\(direction) should be cardinal")
        }
    }
    
    /// Test that diagonal directions are classified correctly at their center angles
    func testDiagonalDirectionsAtCenterAngles() {
        let diagonalCases: [(StickDirection, Double)] = [
            (.upRight, 45.0),
            (.upLeft, 135.0),
            (.downLeft, 225.0),
            (.downRight, 315.0)
        ]
        
        for (expected, angle) in diagonalCases {
            let direction = detector.classifyDirection(angle: angle, cardinalAngle: 22.5)
            XCTAssertEqual(direction, expected, "Angle \(angle) should classify as \(expected)")
            XCTAssertTrue(direction.isDiagonal, "\(direction) should be diagonal")
        }
    }
    
    /// Test boundary conditions at zone edges
    func testZoneBoundaries() {
        let cardinalAngle = 22.5
        
        // Test just inside cardinal zones
        let cardinalBoundaryCases: [(StickDirection, Double)] = [
            (.right, 22.4),
            (.right, 337.6),
            (.up, 67.6),
            (.up, 112.4),
            (.left, 157.6),
            (.left, 202.4),
            (.down, 247.6),
            (.down, 292.4)
        ]
        
        for (expected, angle) in cardinalBoundaryCases {
            let direction = detector.classifyDirection(angle: angle, cardinalAngle: cardinalAngle)
            XCTAssertEqual(direction, expected, "Angle \(angle) should classify as \(expected)")
        }
    }
    
    /// Test that all 8 directions are reachable
    func testAllDirectionsReachable() {
        // Each direction should be reachable at its center angle
        let allDirections = StickDirection.allCases
        
        for direction in allDirections {
            let classified = detector.classifyDirection(angle: direction.centerAngle, cardinalAngle: 22.5)
            XCTAssertEqual(classified, direction, "Direction \(direction) should be reachable at angle \(direction.centerAngle)")
        }
    }
    
    /// Property test: classified direction's center angle should be close to input angle
    func testClassifiedDirectionCenterAngleProximity() {
        property("Classified direction center angle is within 45° of input angle") <- forAll(
            Gen<Double>.fromElements(in: 0.0...360.0)
        ) { (angle: Double) in
            let direction = self.detector.classifyDirection(angle: angle, cardinalAngle: 22.5)
            let centerAngle = direction.centerAngle
            
            // Calculate angular distance (accounting for wrap-around)
            var diff = abs(angle - centerAngle)
            if diff > 180 {
                diff = 360 - diff
            }
            
            // The classified direction's center should be within 45° of the input
            return diff <= 45.0
        }
    }
}
