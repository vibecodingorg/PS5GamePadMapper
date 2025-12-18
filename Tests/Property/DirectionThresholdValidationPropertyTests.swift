import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Direction Threshold Validation
/// **Feature: stick-direction-mapping, Property 9: Direction Threshold Validation**
final class DirectionThresholdValidationPropertyTests: XCTestCase {
    
    // MARK: - Property 9: Direction Threshold Validation
    
    /// **Feature: stick-direction-mapping, Property 9: Direction Threshold Validation**
    /// **Validates: Requirements 2.5**
    ///
    /// *For any* threshold value provided to DirectionInput, the stored threshold
    /// should be clamped to the valid range [0.1, 0.9].
    func testDirectionThresholdClamping() {
        property("Direction threshold is always clamped to [0.1, 0.9]") <- forAll(
            StickType.arbitrary,
            StickDirection.arbitrary,
            // Generate a wide range of threshold values including out-of-range
            Gen.fromElements(of: [-1.0, -0.5, 0.0, 0.05, 0.1, 0.3, 0.5, 0.7, 0.9, 0.95, 1.0, 1.5, 2.0])
        ) { (stick: StickType, direction: StickDirection, inputThreshold: Double) in
            let directionInput = DirectionInput(stick: stick, direction: direction, threshold: inputThreshold)
            
            // Verify threshold is within valid range
            return directionInput.threshold >= 0.1 && directionInput.threshold <= 0.9
        }
    }
    
    /// Additional property: Threshold clamping preserves valid values
    func testValidThresholdPreserved() {
        property("Valid threshold values are preserved exactly") <- forAll(
            StickType.arbitrary,
            StickDirection.arbitrary,
            // Generate only valid threshold values
            Gen.fromElements(of: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9])
        ) { (stick: StickType, direction: StickDirection, validThreshold: Double) in
            let directionInput = DirectionInput(stick: stick, direction: direction, threshold: validThreshold)
            
            // Valid thresholds should be preserved exactly
            return abs(directionInput.threshold - validThreshold) < 0.0001
        }
    }
    
    /// Additional property: Below-minimum threshold clamps to 0.1
    func testBelowMinimumThresholdClampsToMin() {
        property("Threshold below 0.1 clamps to 0.1") <- forAll(
            StickType.arbitrary,
            StickDirection.arbitrary,
            Gen.fromElements(of: [-1.0, -0.5, 0.0, 0.05, 0.09])
        ) { (stick: StickType, direction: StickDirection, lowThreshold: Double) in
            let directionInput = DirectionInput(stick: stick, direction: direction, threshold: lowThreshold)
            
            return abs(directionInput.threshold - 0.1) < 0.0001
        }
    }
    
    /// Additional property: Above-maximum threshold clamps to 0.9
    func testAboveMaximumThresholdClampsToMax() {
        property("Threshold above 0.9 clamps to 0.9") <- forAll(
            StickType.arbitrary,
            StickDirection.arbitrary,
            Gen.fromElements(of: [0.91, 0.95, 1.0, 1.5, 2.0])
        ) { (stick: StickType, direction: StickDirection, highThreshold: Double) in
            let directionInput = DirectionInput(stick: stick, direction: direction, threshold: highThreshold)
            
            return abs(directionInput.threshold - 0.9) < 0.0001
        }
    }
}
