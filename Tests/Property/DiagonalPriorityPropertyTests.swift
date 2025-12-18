import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Diagonal Priority over Cardinals
/// **Feature: stick-direction-mapping, Property 6: Diagonal Priority over Cardinals**
final class DiagonalPriorityPropertyTests: XCTestCase {
    
    private var mappingEngine: MappingEngine!
    
    override func setUp() {
        super.setUp()
        mappingEngine = MappingEngine()
    }
    
    override func tearDown() {
        mappingEngine = nil
        super.tearDown()
    }
    
    // MARK: - Property 6: Diagonal Priority over Cardinals
    
    /// **Feature: stick-direction-mapping, Property 6: Diagonal Priority over Cardinals**
    /// **Validates: Requirements 5.4**
    ///
    /// *For any* diagonal direction input where a diagonal mapping exists, the system should
    /// trigger only the diagonal mapping and not the adjacent cardinal mappings, even if
    /// cardinal mappings are configured.
    func testDiagonalPriorityOverCardinals() {
        let diagonalGen = DiagonalPriorityPropertyTests.diagonalDirectionGen()
        property("Diagonal mapping takes priority over cardinal mappings") <- forAll(
            StickType.arbitrary,
            diagonalGen,
            KeyAction.arbitrary,
            KeyAction.arbitrary,
            KeyAction.arbitrary
        ) { (stick: StickType, diagonal: StickDirection, diagonalKey: KeyAction, cardinalKey1: KeyAction, cardinalKey2: KeyAction) in
            self.mappingEngine.resetDirectionStates()
            
            let adjacentCardinals = diagonal.adjacentCardinals
            guard adjacentCardinals.count == 2 else { return false }
            
            let cardinal1 = adjacentCardinals[0]
            let cardinal2 = adjacentCardinals[1]
            
            // Create mappings for diagonal AND both cardinals
            let diagonalMapping = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: diagonal)),
                trigger: .press,
                action: .keyPress(diagonalKey)
            )
            let cardinalMapping1 = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: cardinal1)),
                trigger: .press,
                action: .keyPress(cardinalKey1)
            )
            let cardinalMapping2 = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: cardinal2)),
                trigger: .press,
                action: .keyPress(cardinalKey2)
            )
            
            let profile = Profile(
                name: "Test",
                mappings: [diagonalMapping, cardinalMapping1, cardinalMapping2]
            )
            self.mappingEngine.activeProfile = profile
            
            let event = DirectionEvent(
                stick: stick,
                direction: diagonal,
                state: .pressed,
                angle: diagonal.centerAngle,
                magnitude: 1.0
            )
            
            let actions = self.mappingEngine.handleDirectionEvent(event)
            
            // Should trigger ONLY the diagonal action (1 action)
            guard actions.count == 1 else { return false }
            
            // Verify it's the diagonal key, not a cardinal key
            if case .keyPress(let key) = actions[0] {
                return key.keyCode == diagonalKey.keyCode
            }
            return false
        }
    }
    
    /// Test that diagonal priority works for all diagonal directions
    func testDiagonalPriorityAllDirections() {
        let diagonals: [StickDirection] = [.upLeft, .upRight, .downLeft, .downRight]
        
        for diagonal in diagonals {
            mappingEngine.resetDirectionStates()
            
            let stick = StickType.left
            let adjacentCardinals = diagonal.adjacentCardinals
            
            // Create diagonal mapping with unique key code
            let diagonalKey = KeyAction(keyCode: 100, modifiers: [])
            let diagonalMapping = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: diagonal)),
                trigger: .press,
                action: .keyPress(diagonalKey)
            )
            
            // Create cardinal mappings with different key codes
            var mappings = [diagonalMapping]
            for (index, cardinal) in adjacentCardinals.enumerated() {
                let cardinalKey = KeyAction(keyCode: UInt16(index), modifiers: [])
                let cardinalMapping = Mapping(
                    input: .direction(DirectionInput(stick: stick, direction: cardinal)),
                    trigger: .press,
                    action: .keyPress(cardinalKey)
                )
                mappings.append(cardinalMapping)
            }
            
            let profile = Profile(name: "Test", mappings: mappings)
            mappingEngine.activeProfile = profile
            
            let event = DirectionEvent(
                stick: stick,
                direction: diagonal,
                state: .pressed,
                angle: diagonal.centerAngle,
                magnitude: 1.0
            )
            
            let actions = mappingEngine.handleDirectionEvent(event)
            
            XCTAssertEqual(actions.count, 1, "Diagonal \(diagonal) should trigger only 1 action")
            if case .keyPress(let key) = actions[0] {
                XCTAssertEqual(key.keyCode, 100, "Should be the diagonal key, not a cardinal key")
            } else {
                XCTFail("Expected keyPress action")
            }
        }
    }
    
    /// Test that diagonal release only releases diagonal, not cardinals
    func testDiagonalPriorityOnRelease() {
        let diagonalGen = DiagonalPriorityPropertyTests.diagonalDirectionGen()
        property("Diagonal release only releases diagonal mapping") <- forAll(
            StickType.arbitrary,
            diagonalGen,
            KeyAction.arbitrary
        ) { (stick: StickType, diagonal: StickDirection, diagonalKey: KeyAction) in
            self.mappingEngine.resetDirectionStates()
            
            let adjacentCardinals = diagonal.adjacentCardinals
            guard adjacentCardinals.count == 2 else { return false }
            
            // Create diagonal and cardinal mappings
            let diagonalMapping = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: diagonal)),
                trigger: .press,
                action: .keyPress(diagonalKey)
            )
            
            var mappings = [diagonalMapping]
            for (index, cardinal) in adjacentCardinals.enumerated() {
                let cardinalKey = KeyAction(keyCode: UInt16(index), modifiers: [])
                let cardinalMapping = Mapping(
                    input: .direction(DirectionInput(stick: stick, direction: cardinal)),
                    trigger: .press,
                    action: .keyPress(cardinalKey)
                )
                mappings.append(cardinalMapping)
            }
            
            let profile = Profile(name: "Test", mappings: mappings)
            self.mappingEngine.activeProfile = profile
            
            // Press diagonal
            let pressEvent = DirectionEvent(
                stick: stick,
                direction: diagonal,
                state: .pressed,
                angle: diagonal.centerAngle,
                magnitude: 1.0
            )
            _ = self.mappingEngine.handleDirectionEvent(pressEvent)
            
            // Release diagonal
            let releaseEvent = DirectionEvent(
                stick: stick,
                direction: diagonal,
                state: .released,
                angle: diagonal.centerAngle,
                magnitude: 0.0
            )
            let releaseActions = self.mappingEngine.handleDirectionEvent(releaseEvent)
            
            // Should only release the diagonal key (1 action)
            guard releaseActions.count == 1 else { return false }
            
            if case .keyRelease(let key) = releaseActions[0] {
                return key.keyCode == diagonalKey.keyCode
            }
            return false
        }
    }
    
    /// Test that cardinal directions still work independently
    func testCardinalDirectionsStillWork() {
        let cardinalGen = DiagonalPriorityPropertyTests.cardinalDirectionGen()
        property("Cardinal directions work when diagonal is also mapped") <- forAll(
            StickType.arbitrary,
            cardinalGen,
            KeyAction.arbitrary
        ) { (stick: StickType, cardinal: StickDirection, cardinalKey: KeyAction) in
            self.mappingEngine.resetDirectionStates()
            
            // Create cardinal mapping
            let cardinalMapping = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: cardinal)),
                trigger: .press,
                action: .keyPress(cardinalKey)
            )
            
            // Also create a diagonal mapping (shouldn't affect cardinal)
            let diagonalKey = KeyAction(keyCode: 99, modifiers: [])
            let diagonalMapping = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: .upLeft)),
                trigger: .press,
                action: .keyPress(diagonalKey)
            )
            
            let profile = Profile(name: "Test", mappings: [cardinalMapping, diagonalMapping])
            self.mappingEngine.activeProfile = profile
            
            // Press cardinal direction
            let event = DirectionEvent(
                stick: stick,
                direction: cardinal,
                state: .pressed,
                angle: cardinal.centerAngle,
                magnitude: 1.0
            )
            
            let actions = self.mappingEngine.handleDirectionEvent(event)
            
            // Should trigger only the cardinal action
            guard actions.count == 1 else { return false }
            
            if case .keyPress(let key) = actions[0] {
                return key.keyCode == cardinalKey.keyCode
            }
            return false
        }
    }
    
    // MARK: - Helpers
    
    /// Generator for diagonal directions only
    static func diagonalDirectionGen() -> Gen<StickDirection> {
        Gen.fromElements(of: [.upLeft, .upRight, .downLeft, .downRight])
    }
    
    /// Generator for cardinal directions only
    static func cardinalDirectionGen() -> Gen<StickDirection> {
        Gen.fromElements(of: [.up, .down, .left, .right])
    }
}
