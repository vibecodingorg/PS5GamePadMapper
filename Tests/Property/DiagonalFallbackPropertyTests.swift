import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Diagonal Fallback to Cardinals
/// **Feature: stick-direction-mapping, Property 5: Diagonal Fallback to Cardinals**
final class DiagonalFallbackPropertyTests: XCTestCase {
    
    private var mappingEngine: MappingEngine!
    
    override func setUp() {
        super.setUp()
        mappingEngine = MappingEngine()
    }
    
    override func tearDown() {
        mappingEngine = nil
        super.tearDown()
    }
    
    // MARK: - Property 5: Diagonal Fallback to Cardinals
    
    /// **Feature: stick-direction-mapping, Property 5: Diagonal Fallback to Cardinals**
    /// **Validates: Requirements 4.4, 5.3**
    ///
    /// *For any* diagonal direction input where no diagonal mapping exists but adjacent cardinal
    /// mappings do, the system should trigger both adjacent cardinal direction mappings simultaneously.
    func testDiagonalFallbackToCardinals() {
        let diagonalGen = DiagonalFallbackPropertyTests.diagonalDirectionGen()
        property("Diagonal without mapping triggers both adjacent cardinals") <- forAll(
            StickType.arbitrary,
            diagonalGen
        ) { (stick: StickType, diagonal: StickDirection) in
            self.mappingEngine.resetDirectionStates()
            
            // Get adjacent cardinals for this diagonal
            let adjacentCardinals = diagonal.adjacentCardinals
            guard adjacentCardinals.count == 2 else { return false }
            
            // Create profile with ONLY cardinal mappings (no diagonal mapping)
            let cardinal1 = adjacentCardinals[0]
            let cardinal2 = adjacentCardinals[1]
            
            let keyAction1 = KeyAction(keyCode: 0, modifiers: [])
            let keyAction2 = KeyAction(keyCode: 1, modifiers: [])
            
            let mapping1 = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: cardinal1)),
                trigger: .press,
                action: .keyPress(keyAction1)
            )
            let mapping2 = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: cardinal2)),
                trigger: .press,
                action: .keyPress(keyAction2)
            )
            
            let profile = Profile(
                name: "Test",
                mappings: [mapping1, mapping2]
            )
            self.mappingEngine.activeProfile = profile
            
            // Create diagonal direction event (pressed)
            let event = DirectionEvent(
                stick: stick,
                direction: diagonal,
                state: .pressed,
                angle: diagonal.centerAngle,
                magnitude: 1.0
            )
            
            // Handle the diagonal event
            let actions = self.mappingEngine.handleDirectionEvent(event)
            
            // Should trigger both cardinal actions
            return actions.count == 2
        }
    }
    
    /// Test that diagonal fallback triggers correct cardinal actions
    func testDiagonalFallbackTriggersCorrectActions() {
        let diagonalGen = DiagonalFallbackPropertyTests.diagonalDirectionGen()
        property("Diagonal fallback triggers the correct cardinal actions") <- forAll(
            StickType.arbitrary,
            diagonalGen,
            KeyAction.arbitrary,
            KeyAction.arbitrary
        ) { (stick: StickType, diagonal: StickDirection, key1: KeyAction, key2: KeyAction) in
            self.mappingEngine.resetDirectionStates()
            
            let adjacentCardinals = diagonal.adjacentCardinals
            guard adjacentCardinals.count == 2 else { return false }
            
            let cardinal1 = adjacentCardinals[0]
            let cardinal2 = adjacentCardinals[1]
            
            let mapping1 = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: cardinal1)),
                trigger: .press,
                action: .keyPress(key1)
            )
            let mapping2 = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: cardinal2)),
                trigger: .press,
                action: .keyPress(key2)
            )
            
            let profile = Profile(
                name: "Test",
                mappings: [mapping1, mapping2]
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
            
            // Verify both expected actions are present
            let hasKey1 = actions.contains { action in
                if case .keyPress(let k) = action {
                    return k.keyCode == key1.keyCode
                }
                return false
            }
            let hasKey2 = actions.contains { action in
                if case .keyPress(let k) = action {
                    return k.keyCode == key2.keyCode
                }
                return false
            }
            
            return hasKey1 && hasKey2
        }
    }
    
    /// Test that diagonal fallback works with only one cardinal mapped
    func testDiagonalFallbackWithPartialCardinals() {
        let diagonalGen = DiagonalFallbackPropertyTests.diagonalDirectionGen()
        property("Diagonal fallback works when only one cardinal is mapped") <- forAll(
            StickType.arbitrary,
            diagonalGen,
            KeyAction.arbitrary
        ) { (stick: StickType, diagonal: StickDirection, keyAction: KeyAction) in
            self.mappingEngine.resetDirectionStates()
            
            let adjacentCardinals = diagonal.adjacentCardinals
            guard adjacentCardinals.count == 2 else { return false }
            
            // Only map the first cardinal
            let cardinal1 = adjacentCardinals[0]
            
            let mapping = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: cardinal1)),
                trigger: .press,
                action: .keyPress(keyAction)
            )
            
            let profile = Profile(
                name: "Test",
                mappings: [mapping]
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
            
            // Should trigger only the one mapped cardinal
            return actions.count == 1
        }
    }
    
    /// Test that diagonal fallback emits release events for cardinals
    func testDiagonalFallbackRelease() {
        let diagonalGen = DiagonalFallbackPropertyTests.diagonalDirectionGen()
        property("Diagonal release triggers cardinal release events") <- forAll(
            StickType.arbitrary,
            diagonalGen
        ) { (stick: StickType, diagonal: StickDirection) in
            self.mappingEngine.resetDirectionStates()
            
            let adjacentCardinals = diagonal.adjacentCardinals
            guard adjacentCardinals.count == 2 else { return false }
            
            let cardinal1 = adjacentCardinals[0]
            let cardinal2 = adjacentCardinals[1]
            
            let keyAction1 = KeyAction(keyCode: 0, modifiers: [])
            let keyAction2 = KeyAction(keyCode: 1, modifiers: [])
            
            let mapping1 = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: cardinal1)),
                trigger: .press,
                action: .keyPress(keyAction1)
            )
            let mapping2 = Mapping(
                input: .direction(DirectionInput(stick: stick, direction: cardinal2)),
                trigger: .press,
                action: .keyPress(keyAction2)
            )
            
            let profile = Profile(
                name: "Test",
                mappings: [mapping1, mapping2]
            )
            self.mappingEngine.activeProfile = profile
            
            // First press the diagonal
            let pressEvent = DirectionEvent(
                stick: stick,
                direction: diagonal,
                state: .pressed,
                angle: diagonal.centerAngle,
                magnitude: 1.0
            )
            _ = self.mappingEngine.handleDirectionEvent(pressEvent)
            
            // Then release the diagonal
            let releaseEvent = DirectionEvent(
                stick: stick,
                direction: diagonal,
                state: .released,
                angle: diagonal.centerAngle,
                magnitude: 0.0
            )
            let releaseActions = self.mappingEngine.handleDirectionEvent(releaseEvent)
            
            // Should emit release actions for both cardinals
            let releaseCount = releaseActions.filter { action in
                if case .keyRelease = action { return true }
                return false
            }.count
            
            return releaseCount == 2
        }
    }
    
    /// Test that no actions are triggered when no cardinals are mapped
    func testDiagonalFallbackNoMappings() {
        let diagonalGen = DiagonalFallbackPropertyTests.diagonalDirectionGen()
        property("Diagonal with no cardinal mappings triggers no actions") <- forAll(
            StickType.arbitrary,
            diagonalGen
        ) { (stick: StickType, diagonal: StickDirection) in
            self.mappingEngine.resetDirectionStates()
            
            // Empty profile - no mappings
            let profile = Profile(name: "Test", mappings: [])
            self.mappingEngine.activeProfile = profile
            
            let event = DirectionEvent(
                stick: stick,
                direction: diagonal,
                state: .pressed,
                angle: diagonal.centerAngle,
                magnitude: 1.0
            )
            
            let actions = self.mappingEngine.handleDirectionEvent(event)
            
            return actions.isEmpty
        }
    }
    
    // MARK: - Helpers
    
    /// Generator for diagonal directions only
    static func diagonalDirectionGen() -> Gen<StickDirection> {
        Gen.fromElements(of: [.upLeft, .upRight, .downLeft, .downRight])
    }
}
