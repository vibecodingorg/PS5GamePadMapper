import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Direction Mapping Priority over Axis
/// **Feature: stick-direction-mapping, Property 8: Direction Mapping Priority over Axis**
final class DirectionPriorityOverAxisPropertyTests: XCTestCase {
    
    private var mappingEngine: MappingEngine!
    
    override func setUp() {
        super.setUp()
        mappingEngine = MappingEngine()
    }
    
    override func tearDown() {
        mappingEngine = nil
        super.tearDown()
    }
    
    // MARK: - Property 8: Direction Mapping Priority over Axis
    
    /// **Feature: stick-direction-mapping, Property 8: Direction Mapping Priority over Axis**
    /// **Validates: Requirements 7.3**
    ///
    /// *For any* Profile containing both axis mappings and direction mappings for the same stick,
    /// when processing stick input, direction mappings should take priority and axis mappings
    /// should not be triggered.
    func testDirectionMappingPriorityOverAxis() {
        property("Direction mappings take priority over axis mappings") <- forAll(
            StickType.arbitrary,
            StickDirection.arbitrary,
            KeyAction.arbitrary
        ) { (stick: StickType, direction: StickDirection, directionKey: KeyAction) in
            self.mappingEngine.resetDirectionStates()
            
            // Get the axis types for this stick
            let (axisX, axisY) = self.axisTypesForStick(stick)
            
            // Create direction mapping
            let directionMapping = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: direction)),
                trigger: .press,
                action: .keyPress(directionKey)
            )
            
            // Create axis mappings for the same stick
            let axisXMapping = Mapping(
                input: .axis(axisX),
                trigger: .press,
                action: .mouseMove(MouseMoveAction(sensitivity: 1.0, deadzone: 0.1, curve: .linear))
            )
            let axisYMapping = Mapping(
                input: .axis(axisY),
                trigger: .press,
                action: .mouseMove(MouseMoveAction(sensitivity: 1.0, deadzone: 0.1, curve: .linear))
            )
            
            let profile = Profile(
                name: "Test",
                mappings: [directionMapping, axisXMapping, axisYMapping]
            )
            self.mappingEngine.activeProfile = profile
            
            // Process axis event for the stick with direction mappings
            let axisEvent = AxisEvent(axis: axisX, normalizedValue: 0.8)
            let axisActions = self.mappingEngine.handleAxisEvent(axisEvent)
            
            // Axis actions should be empty because direction mappings exist for this stick
            return axisActions.isEmpty
        }
    }
    
    /// Test that axis mappings work when no direction mappings exist
    func testAxisMappingsWorkWithoutDirectionMappings() {
        property("Axis mappings work when no direction mappings exist") <- forAll(
            StickType.arbitrary
        ) { (stick: StickType) in
            self.mappingEngine.resetDirectionStates()
            
            let (axisX, _) = self.axisTypesForStick(stick)
            
            // Create only axis mapping (no direction mappings)
            let axisMapping = Mapping(
                input: .axis(axisX),
                trigger: .press,
                action: .mouseMove(MouseMoveAction(sensitivity: 1.0, deadzone: 0.1, curve: .linear))
            )
            
            let profile = Profile(name: "Test", mappings: [axisMapping])
            self.mappingEngine.activeProfile = profile
            
            // Process axis event
            let axisEvent = AxisEvent(axis: axisX, normalizedValue: 0.8)
            let axisActions = self.mappingEngine.handleAxisEvent(axisEvent)
            
            // Should have axis action since no direction mappings exist
            return axisActions.count == 1
        }
    }
    
    /// Test that direction mappings on one stick don't affect axis mappings on another stick
    func testDirectionMappingsOnlyAffectSameStick() {
        property("Direction mappings only affect axis mappings on the same stick") <- forAll(
            StickDirection.arbitrary
        ) { (direction: StickDirection) in
            self.mappingEngine.resetDirectionStates()
            
            // Create direction mapping for LEFT stick
            let directionKey = KeyAction(keyCode: 0, modifiers: [])
            let directionMapping = Mapping(
                input: .direction(DirectionInput(stick: .left, direction: direction)),
                trigger: .press,
                action: .keyPress(directionKey)
            )
            
            // Create axis mapping for RIGHT stick
            let axisMapping = Mapping(
                input: .axis(.rightStickX),
                trigger: .press,
                action: .mouseMove(MouseMoveAction(sensitivity: 1.0, deadzone: 0.1, curve: .linear))
            )
            
            let profile = Profile(name: "Test", mappings: [directionMapping, axisMapping])
            self.mappingEngine.activeProfile = profile
            
            // Process axis event for RIGHT stick
            let axisEvent = AxisEvent(axis: .rightStickX, normalizedValue: 0.8)
            let axisActions = self.mappingEngine.handleAxisEvent(axisEvent)
            
            // Right stick axis should work since direction mapping is on left stick
            return axisActions.count == 1
        }
    }
    
    /// Test that trigger axes are not affected by direction mappings
    func testTriggerAxesNotAffectedByDirectionMappings() {
        property("Trigger axes are not affected by direction mappings") <- forAll(
            StickType.arbitrary,
            StickDirection.arbitrary,
            Gen.fromElements(of: [AxisType.l2Trigger, AxisType.r2Trigger])
        ) { (stick: StickType, direction: StickDirection, triggerAxis: AxisType) in
            self.mappingEngine.resetDirectionStates()
            
            // Create direction mapping for a stick
            let directionKey = KeyAction(keyCode: 0, modifiers: [])
            let directionMapping = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: direction)),
                trigger: .press,
                action: .keyPress(directionKey)
            )
            
            // Create trigger axis mapping
            let triggerKey = KeyAction(keyCode: 1, modifiers: [])
            let triggerMapping = Mapping(
                input: .axis(triggerAxis),
                trigger: .press,
                action: .keyPress(triggerKey)
            )
            
            let profile = Profile(name: "Test", mappings: [directionMapping, triggerMapping])
            self.mappingEngine.activeProfile = profile
            
            // Process trigger axis event
            let axisEvent = AxisEvent(axis: triggerAxis, normalizedValue: 0.8)
            let axisActions = self.mappingEngine.handleAxisEvent(axisEvent)
            
            // Trigger should work regardless of direction mappings
            return axisActions.count == 1
        }
    }
    
    /// Test hasDirectionMappings helper function
    func testHasDirectionMappingsHelper() {
        property("hasDirectionMappings correctly identifies sticks with direction mappings") <- forAll(
            StickType.arbitrary,
            StickDirection.arbitrary
        ) { (stick: StickType, direction: StickDirection) in
            self.mappingEngine.resetDirectionStates()
            
            // Create direction mapping for the stick
            let directionKey = KeyAction(keyCode: 0, modifiers: [])
            let directionMapping = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: direction)),
                trigger: .press,
                action: .keyPress(directionKey)
            )
            
            let profile = Profile(name: "Test", mappings: [directionMapping])
            self.mappingEngine.activeProfile = profile
            
            // Check that hasDirectionMappings returns true for the stick with mapping
            let hasMapping = self.mappingEngine.hasDirectionMappings(for: stick)
            
            // Check that the other stick doesn't have direction mappings
            let otherStick: StickType = stick == .left ? .right : .left
            let otherHasMapping = self.mappingEngine.hasDirectionMappings(for: otherStick)
            
            return hasMapping && !otherHasMapping
        }
    }
    
    /// Test that both X and Y axes are blocked when direction mappings exist
    func testBothAxesBlockedByDirectionMappings() {
        mappingEngine.resetDirectionStates()
        
        // Create direction mapping for left stick
        let directionKey = KeyAction(keyCode: 0, modifiers: [])
        let directionMapping = Mapping(
            input: .direction(DirectionInput(stick: .left, direction: .up)),
            trigger: .press,
            action: .keyPress(directionKey)
        )
        
        // Create axis mappings for both X and Y
        let axisXMapping = Mapping(
            input: .axis(.leftStickX),
            trigger: .press,
            action: .mouseMove(MouseMoveAction())
        )
        let axisYMapping = Mapping(
            input: .axis(.leftStickY),
            trigger: .press,
            action: .mouseMove(MouseMoveAction())
        )
        
        let profile = Profile(name: "Test", mappings: [directionMapping, axisXMapping, axisYMapping])
        mappingEngine.activeProfile = profile
        
        // Both X and Y axis events should return empty
        let xActions = mappingEngine.handleAxisEvent(AxisEvent(axis: .leftStickX, normalizedValue: 0.8))
        let yActions = mappingEngine.handleAxisEvent(AxisEvent(axis: .leftStickY, normalizedValue: 0.8))
        
        XCTAssertTrue(xActions.isEmpty, "X axis should be blocked by direction mapping")
        XCTAssertTrue(yActions.isEmpty, "Y axis should be blocked by direction mapping")
    }
    
    // MARK: - Helpers
    
    /// Get the X and Y axis types for a stick
    private func axisTypesForStick(_ stick: StickType) -> (AxisType, AxisType) {
        switch stick {
        case .left:
            return (.leftStickX, .leftStickY)
        case .right:
            return (.rightStickX, .rightStickY)
        }
    }
}
