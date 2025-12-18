import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for modifier key ordering
/// **Feature: ps5-gamepad-mapper, Property 3: Modifier Key Ordering**
final class ModifierKeyOrderingPropertyTests: XCTestCase {
    
    private var eventEmitter: EventEmitter!
    
    override func setUp() {
        super.setUp()
        eventEmitter = EventEmitter()
        eventEmitter.recordEvents = true
    }
    
    override func tearDown() {
        eventEmitter = nil
        super.tearDown()
    }
    
    // MARK: - Property 3: Modifier Key Ordering
    
    /// **Feature: ps5-gamepad-mapper, Property 3: Modifier Key Ordering**
    /// **Validates: Requirements 4.4**
    ///
    /// *For any* key action with modifiers, when emitting the key event sequence,
    /// all modifier keys (Cmd, Ctrl, Alt, Shift) SHALL be emitted before the primary key.
    func testModifierKeysEmittedBeforePrimaryKey() {
        property("Modifier keys are emitted before the primary key") <- forAll { (input: KeyActionInput) in
            self.eventEmitter.clearRecordedEvents()
            
            // Emit a key down with modifiers
            self.eventEmitter.emitKeyDown(input.keyCode, modifiers: input.modifiers)
            
            let events = self.eventEmitter.emittedEvents
            
            // Find the index of the primary key down event
            guard let primaryKeyIndex = events.firstIndex(where: { event in
                if case .keyDown(let keyCode, _) = event {
                    return keyCode == input.keyCode
                }
                return false
            }) else {
                // If no modifiers, there should be a key down event
                return input.modifiers.isEmpty || !events.isEmpty
            }
            
            // All modifier down events should come before the primary key
            for (index, event) in events.enumerated() {
                if case .modifierDown(_) = event {
                    if index >= primaryKeyIndex {
                        return false // Modifier came after primary key
                    }
                }
            }
            
            return true
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 3: Modifier Key Ordering**
    /// **Validates: Requirements 4.4**
    ///
    /// Verify that modifiers are emitted in the correct order: Cmd, Ctrl, Alt, Shift
    func testModifierOrderIsConsistent() {
        property("Modifiers are emitted in order: Cmd, Ctrl, Alt, Shift") <- forAll { (input: KeyActionInput) in
            self.eventEmitter.clearRecordedEvents()
            
            self.eventEmitter.emitKeyDown(input.keyCode, modifiers: input.modifiers)
            
            let modifierOrder = self.eventEmitter.getModifierOrder(from: self.eventEmitter.emittedEvents)
            
            // Expected order based on which modifiers are present
            var expectedOrder: [KeyModifiers] = []
            if input.modifiers.contains(.command) { expectedOrder.append(.command) }
            if input.modifiers.contains(.control) { expectedOrder.append(.control) }
            if input.modifiers.contains(.option) { expectedOrder.append(.option) }
            if input.modifiers.contains(.shift) { expectedOrder.append(.shift) }
            
            return modifierOrder == expectedOrder
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 3: Modifier Key Ordering**
    /// **Validates: Requirements 4.4**
    ///
    /// Verify that all specified modifiers are actually emitted
    func testAllModifiersAreEmitted() {
        property("All specified modifiers are emitted") <- forAll { (input: KeyActionInput) in
            self.eventEmitter.clearRecordedEvents()
            
            self.eventEmitter.emitKeyDown(input.keyCode, modifiers: input.modifiers)
            
            let emittedModifiers = Set(self.eventEmitter.getModifierOrder(from: self.eventEmitter.emittedEvents))
            let expectedModifiers = Set(input.modifiers.orderedModifiers)
            
            return emittedModifiers == expectedModifiers
        }
    }
    
    /// **Feature: ps5-gamepad-mapper, Property 3: Modifier Key Ordering**
    /// **Validates: Requirements 4.4**
    ///
    /// Verify that key up releases modifiers in reverse order
    func testModifiersReleasedInReverseOrder() {
        property("Modifiers are released in reverse order after key up") <- forAll { (input: KeyActionInput) in
            self.eventEmitter.clearRecordedEvents()
            
            // Emit key down then key up
            self.eventEmitter.emitKeyDown(input.keyCode, modifiers: input.modifiers)
            self.eventEmitter.emitKeyUp(input.keyCode, modifiers: input.modifiers)
            
            let events = self.eventEmitter.emittedEvents
            
            // Find the primary key up event
            guard let primaryKeyUpIndex = events.firstIndex(where: { event in
                if case .keyUp(let keyCode, _) = event {
                    return keyCode == input.keyCode
                }
                return false
            }) else {
                return input.modifiers.isEmpty || !events.isEmpty
            }
            
            // Get modifier up events after the primary key up
            var modifierUpOrder: [KeyModifiers] = []
            for index in (primaryKeyUpIndex + 1)..<events.count {
                if case .modifierUp(let modifier) = events[index] {
                    modifierUpOrder.append(modifier)
                }
            }
            
            // Expected reverse order
            var expectedReverseOrder: [KeyModifiers] = []
            if input.modifiers.contains(.shift) { expectedReverseOrder.append(.shift) }
            if input.modifiers.contains(.option) { expectedReverseOrder.append(.option) }
            if input.modifiers.contains(.control) { expectedReverseOrder.append(.control) }
            if input.modifiers.contains(.command) { expectedReverseOrder.append(.command) }
            
            return modifierUpOrder == expectedReverseOrder
        }
    }
}
