import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Direction State Transitions
/// **Feature: stick-direction-mapping, Property 4: Direction State Transitions**
final class DirectionStateTransitionsPropertyTests: XCTestCase {
    
    private var detector: DirectionDetector!
    
    override func setUp() {
        super.setUp()
        detector = DirectionDetector()
    }
    
    override func tearDown() {
        detector = nil
        super.tearDown()
    }
    
    // MARK: - Property 4: Direction State Transitions
    
    /// **Feature: stick-direction-mapping, Property 4: Direction State Transitions**
    /// **Validates: Requirements 1.5, 2.4, 4.2, 4.3, 6.4, 6.5**
    ///
    /// *For any* sequence of stick positions, when transitioning from one direction to another,
    /// the system should emit release events for the old direction before press events for the
    /// new direction. When the stick is held in the same direction, no repeated press events
    /// should be emitted.
    func testReleaseBeforePressOnDirectionChange() {
        property("Release events come before press events on direction change") <- forAll(
            StickType.arbitrary,
            StickDirection.arbitrary,
            StickDirection.arbitrary.suchThat { $0 != StickDirection.right } // Ensure different from initial
        ) { (stick: StickType, _, newDirection: StickDirection) in
            self.detector.reset()
            
            let config = DirectionDetector.Config(deadzone: 0.0, threshold: 0.3, cardinalAngle: 22.5)
            
            // First, activate right direction
            _ = self.detector.processStickInput(x: 1.0, y: 0.0, stick: stick, config: config)
            
            // Now change to a different direction
            let newAngle = newDirection.centerAngle * .pi / 180.0
            let x = cos(newAngle)
            let y = sin(newAngle)
            
            let events = self.detector.processStickInput(x: x, y: y, stick: stick, config: config)
            
            // Find indices of release and press events
            var releaseIndex: Int?
            var pressIndex: Int?
            
            for (index, event) in events.enumerated() {
                if event.state == .released && releaseIndex == nil {
                    releaseIndex = index
                }
                if event.state == .pressed && pressIndex == nil {
                    pressIndex = index
                }
            }
            
            // If both events exist, release should come before press
            if let rIdx = releaseIndex, let pIdx = pressIndex {
                return rIdx < pIdx
            }
            
            // If only one or neither exists, that's also valid
            return true
        }
    }
    
    /// Test that holding in same direction doesn't emit repeated press events
    func testNoRepeatedPressWhenHeld() {
        property("No repeated press events when direction is held") <- forAll(
            StickType.arbitrary
        ) { (stick: StickType) in
            self.detector.reset()
            
            let config = DirectionDetector.Config(deadzone: 0.0, threshold: 0.3, cardinalAngle: 22.5)
            
            // First press
            let firstEvents = self.detector.processStickInput(x: 1.0, y: 0.0, stick: stick, config: config)
            let firstPressCount = firstEvents.filter { $0.state == .pressed }.count
            guard firstPressCount == 1 else { return false }
            
            // Hold in same position (multiple times)
            for _ in 0..<5 {
                let holdEvents = self.detector.processStickInput(x: 1.0, y: 0.0, stick: stick, config: config)
                let holdPressCount = holdEvents.filter { $0.state == .pressed }.count
                if holdPressCount > 0 {
                    return false // Should not have any press events while holding
                }
            }
            
            return true
        }
    }
    
    /// Test that release event is emitted when returning to center
    func testReleaseOnReturnToCenter() {
        property("Release event emitted when returning to center") <- forAll(
            StickType.arbitrary,
            StickDirection.arbitrary
        ) { (stick: StickType, direction: StickDirection) in
            self.detector.reset()
            
            let config = DirectionDetector.Config(deadzone: 0.0, threshold: 0.3, cardinalAngle: 22.5)
            
            // Activate direction
            let angle = direction.centerAngle * .pi / 180.0
            let x = cos(angle)
            let y = sin(angle)
            _ = self.detector.processStickInput(x: x, y: y, stick: stick, config: config)
            
            // Return to center
            let releaseEvents = self.detector.processStickInput(x: 0.0, y: 0.0, stick: stick, config: config)
            
            // Should have exactly one release event
            let releaseCount = releaseEvents.filter { $0.state == .released }.count
            return releaseCount == 1
        }
    }
    
    /// Test that press event contains correct direction
    func testPressEventContainsCorrectDirection() {
        property("Press event contains the correct direction") <- forAll(
            StickType.arbitrary,
            StickDirection.arbitrary
        ) { (stick: StickType, direction: StickDirection) in
            self.detector.reset()
            
            let config = DirectionDetector.Config(deadzone: 0.0, threshold: 0.3, cardinalAngle: 22.5)
            
            // Activate direction at its center angle
            let angle = direction.centerAngle * .pi / 180.0
            let x = cos(angle)
            let y = sin(angle)
            let events = self.detector.processStickInput(x: x, y: y, stick: stick, config: config)
            
            // Find press event
            let pressEvent = events.first { $0.state == .pressed }
            
            // Press event should exist and have correct direction
            guard let event = pressEvent else { return false }
            return event.direction == direction && event.stick == stick
        }
    }
    
    /// Test that events contain valid angle and magnitude
    func testEventsContainValidAngleAndMagnitude() {
        property("Events contain valid angle (0-360) and magnitude (0-1.5)") <- forAll(
            Gen<Double>.fromElements(in: -1.0...1.0),
            Gen<Double>.fromElements(in: -1.0...1.0),
            StickType.arbitrary
        ) { (x: Double, y: Double, stick: StickType) in
            self.detector.reset()
            
            let config = DirectionDetector.Config(deadzone: 0.0, threshold: 0.3, cardinalAngle: 22.5)
            let events = self.detector.processStickInput(x: x, y: y, stick: stick, config: config)
            
            // All events should have valid angle and magnitude
            for event in events {
                if event.angle < 0 || event.angle > 360 {
                    return false
                }
                if event.magnitude < 0 || event.magnitude > 1.5 {
                    return false
                }
            }
            
            return true
        }
    }
    
    /// Test direction change sequence
    func testDirectionChangeSequence() {
        // Test a specific sequence: right -> up -> left -> down -> center
        detector.reset()
        
        let config = DirectionDetector.Config(deadzone: 0.0, threshold: 0.3, cardinalAngle: 22.5)
        let stick = StickType.left
        
        // Right
        let rightEvents = detector.processStickInput(x: 1.0, y: 0.0, stick: stick, config: config)
        XCTAssertEqual(rightEvents.count, 1)
        XCTAssertEqual(rightEvents[0].state, .pressed)
        XCTAssertEqual(rightEvents[0].direction, .right)
        
        // Up (should release right, then press up)
        let upEvents = detector.processStickInput(x: 0.0, y: 1.0, stick: stick, config: config)
        XCTAssertEqual(upEvents.count, 2)
        XCTAssertEqual(upEvents[0].state, .released)
        XCTAssertEqual(upEvents[0].direction, .right)
        XCTAssertEqual(upEvents[1].state, .pressed)
        XCTAssertEqual(upEvents[1].direction, .up)
        
        // Left (should release up, then press left)
        let leftEvents = detector.processStickInput(x: -1.0, y: 0.0, stick: stick, config: config)
        XCTAssertEqual(leftEvents.count, 2)
        XCTAssertEqual(leftEvents[0].state, .released)
        XCTAssertEqual(leftEvents[0].direction, .up)
        XCTAssertEqual(leftEvents[1].state, .pressed)
        XCTAssertEqual(leftEvents[1].direction, .left)
        
        // Center (should release left)
        let centerEvents = detector.processStickInput(x: 0.0, y: 0.0, stick: stick, config: config)
        XCTAssertEqual(centerEvents.count, 1)
        XCTAssertEqual(centerEvents[0].state, .released)
        XCTAssertEqual(centerEvents[0].direction, .left)
    }
}
