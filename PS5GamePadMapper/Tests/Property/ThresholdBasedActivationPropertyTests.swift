import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Threshold-based Direction Activation
/// **Feature: stick-direction-mapping, Property 3: Threshold-based Direction Activation**
final class ThresholdBasedActivationPropertyTests: XCTestCase {
    
    private var detector: DirectionDetector!
    
    override func setUp() {
        super.setUp()
        detector = DirectionDetector()
    }
    
    override func tearDown() {
        detector = nil
        super.tearDown()
    }
    
    // MARK: - Property 3: Threshold-based Direction Activation
    
    /// **Feature: stick-direction-mapping, Property 3: Threshold-based Direction Activation**
    /// **Validates: Requirements 1.2, 6.2, 6.3**
    ///
    /// *For any* stick position (x, y) and threshold value, a direction should only be detected
    /// when the magnitude (sqrt(x² + y²)) exceeds the threshold. Positions with magnitude below
    /// the threshold should report no active direction.
    func testThresholdBasedActivation() {
        property("Direction only detected when magnitude exceeds threshold") <- forAll(
            Gen<Double>.fromElements(in: -1.0...1.0),
            Gen<Double>.fromElements(in: -1.0...1.0),
            StickType.arbitrary,
            Gen<Double>.fromElements(of: [0.1, 0.3, 0.5, 0.7, 0.9])
        ) { (x: Double, y: Double, stick: StickType, threshold: Double) in
            // Reset detector state
            self.detector.reset()
            
            let config = DirectionDetector.Config(deadzone: 0.0, threshold: threshold, cardinalAngle: 22.5)
            let magnitude = self.detector.calculateMagnitude(x: x, y: y)
            
            let events = self.detector.processStickInput(x: x, y: y, stick: stick, config: config)
            let activeDirections = self.detector.getActiveDirections(for: stick)
            
            if magnitude > threshold {
                // Should have detected a direction (press event)
                let hasPressEvent = events.contains { $0.state == .pressed }
                return hasPressEvent && !activeDirections.isEmpty
            } else {
                // Should not have detected any direction
                return activeDirections.isEmpty
            }
        }
    }
    
    /// Test that positions below threshold produce no direction
    func testBelowThresholdNoDirection() {
        property("Positions below threshold produce no direction") <- forAll(
            StickType.arbitrary,
            Gen<Double>.fromElements(of: [0.3, 0.5, 0.7])
        ) { (stick: StickType, threshold: Double) in
            self.detector.reset()
            
            // Generate position with magnitude below threshold
            let scaleFactor = threshold * 0.5 // Half the threshold
            let x = scaleFactor * 0.707 // 45 degree angle
            let y = scaleFactor * 0.707
            
            let config = DirectionDetector.Config(deadzone: 0.0, threshold: threshold, cardinalAngle: 22.5)
            let events = self.detector.processStickInput(x: x, y: y, stick: stick, config: config)
            let activeDirections = self.detector.getActiveDirections(for: stick)
            
            // Should have no press events and no active directions
            let noPressEvents = !events.contains { $0.state == .pressed }
            return noPressEvents && activeDirections.isEmpty
        }
    }
    
    /// Test that positions above threshold produce a direction
    func testAboveThresholdProducesDirection() {
        property("Positions above threshold produce a direction") <- forAll(
            StickType.arbitrary,
            Gen<Double>.fromElements(of: [0.1, 0.3, 0.5])
        ) { (stick: StickType, threshold: Double) in
            self.detector.reset()
            
            // Generate position with magnitude above threshold
            let scaleFactor = threshold + 0.2 // Above threshold
            let x = scaleFactor * 0.707 // 45 degree angle
            let y = scaleFactor * 0.707
            
            let config = DirectionDetector.Config(deadzone: 0.0, threshold: threshold, cardinalAngle: 22.5)
            let events = self.detector.processStickInput(x: x, y: y, stick: stick, config: config)
            let activeDirections = self.detector.getActiveDirections(for: stick)
            
            // Should have press event and active direction
            let hasPressEvent = events.contains { $0.state == .pressed }
            return hasPressEvent && !activeDirections.isEmpty
        }
    }
    
    /// Test magnitude calculation accuracy
    func testMagnitudeCalculation() {
        property("Magnitude is calculated correctly as sqrt(x² + y²)") <- forAll(
            Gen<Double>.fromElements(in: -1.0...1.0),
            Gen<Double>.fromElements(in: -1.0...1.0)
        ) { (x: Double, y: Double) in
            let magnitude = self.detector.calculateMagnitude(x: x, y: y)
            let expected = sqrt(x * x + y * y)
            
            return abs(magnitude - expected) < 0.0001
        }
    }
    
    /// Test that returning to center releases direction
    func testReturnToCenterReleasesDirection() {
        property("Returning to center releases active direction") <- forAll(
            StickType.arbitrary
        ) { (stick: StickType) in
            self.detector.reset()
            
            let config = DirectionDetector.Config(deadzone: 0.0, threshold: 0.5, cardinalAngle: 22.5)
            
            // First, activate a direction
            _ = self.detector.processStickInput(x: 1.0, y: 0.0, stick: stick, config: config)
            let activeAfterPress = self.detector.getActiveDirections(for: stick)
            guard !activeAfterPress.isEmpty else { return false }
            
            // Return to center
            let releaseEvents = self.detector.processStickInput(x: 0.0, y: 0.0, stick: stick, config: config)
            let activeAfterRelease = self.detector.getActiveDirections(for: stick)
            
            // Should have release event and no active directions
            let hasReleaseEvent = releaseEvents.contains { $0.state == .released }
            return hasReleaseEvent && activeAfterRelease.isEmpty
        }
    }
}
