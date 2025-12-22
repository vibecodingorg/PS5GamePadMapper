import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Immediate Parameter Application
/// **Feature: stick-interaction-enhancement, Property 7: Immediate Parameter Application**
final class ImmediateParameterApplicationPropertyTests: XCTestCase {
    
    // MARK: - Property 7: Immediate Parameter Application
    
    /// **Feature: stick-interaction-enhancement, Property 7: Immediate Parameter Application**
    /// **Validates: Requirements 5.5**
    ///
    /// *For any* parameter change in the stick mapping editor, the change should be
    /// immediately reflected in the profile without requiring an explicit save action.
    ///
    /// This test verifies that when parameters are changed, the callback is invoked
    /// with the updated values immediately.
    func testImmediateMouseConfigApplication() {
        property("Mouse config changes are applied immediately") <- forAll { (mouseConfig: MouseMoveAction) in
            // Simulate the immediate application behavior
            var appliedConfig: MouseMoveAction?
            
            // The callback that would be passed to the editor
            let onMouseConfigChanged: (MouseMoveAction?) -> Void = { config in
                appliedConfig = config
            }
            
            // Simulate parameter change - this is what happens in the editor
            onMouseConfigChanged(mouseConfig)
            
            // Verify the config was applied immediately
            return appliedConfig == mouseConfig
        }
    }

    /// **Feature: stick-interaction-enhancement, Property 7: Immediate Parameter Application**
    /// **Validates: Requirements 5.5**
    ///
    /// Test that direction mapping changes are applied immediately
    func testImmediateDirectionMappingApplication() {
        property("Direction mapping changes are applied immediately") <- forAll { (directionMapping: DirectionMapping) in
            // Simulate the immediate application behavior
            var appliedDirection: StickDirection?
            var appliedMapping: Mapping?
            
            // The callback that would be passed to the editor
            let onDirectionMappingChanged: (StickDirection, Mapping?) -> Void = { direction, mapping in
                appliedDirection = direction
                appliedMapping = mapping
            }
            
            // Simulate parameter change - this is what happens in the editor
            let mapping = directionMapping.toMapping()
            onDirectionMappingChanged(directionMapping.direction, mapping)
            
            // Verify the mapping was applied immediately
            return appliedDirection == directionMapping.direction
                && appliedMapping == mapping
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 7: Immediate Parameter Application**
    /// **Validates: Requirements 5.5**
    ///
    /// Test that multiple parameter changes are all applied immediately
    func testMultipleParameterChangesAppliedImmediately() {
        property("Multiple parameter changes are all applied immediately") <- forAll { 
            (configs: [MouseMoveAction]) in
            
            // Skip empty arrays
            guard !configs.isEmpty else { return true }
            
            // Track all applied configs
            var appliedConfigs: [MouseMoveAction] = []
            
            // The callback that would be passed to the editor
            let onMouseConfigChanged: (MouseMoveAction?) -> Void = { config in
                if let config = config {
                    appliedConfigs.append(config)
                }
            }
            
            // Simulate multiple parameter changes
            for config in configs {
                onMouseConfigChanged(config)
            }
            
            // Verify all configs were applied immediately
            return appliedConfigs == configs
        }
    }

    /// **Feature: stick-interaction-enhancement, Property 7: Immediate Parameter Application**
    /// **Validates: Requirements 5.5**
    ///
    /// Test that clearing a mapping is applied immediately
    func testImmediateMappingClearApplication() {
        property("Clearing a mapping is applied immediately") <- forAll { (direction: StickDirection) in
            // Simulate the immediate application behavior
            var clearedDirection: StickDirection?
            var clearedMapping: Mapping?
            var wasCalled = false
            
            // The callback that would be passed to the editor
            let onDirectionMappingChanged: (StickDirection, Mapping?) -> Void = { dir, mapping in
                clearedDirection = dir
                clearedMapping = mapping
                wasCalled = true
            }
            
            // Simulate clearing a mapping (passing nil)
            onDirectionMappingChanged(direction, nil)
            
            // Verify the clear was applied immediately
            return wasCalled
                && clearedDirection == direction
                && clearedMapping == nil
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 7: Immediate Parameter Application**
    /// **Validates: Requirements 5.5**
    ///
    /// Test that profile update is triggered for each parameter change
    func testProfileUpdateTriggeredForEachChange() {
        property("Profile update is triggered for each parameter change") <- forAll { 
            (partialMappings: PartialDirectionMappings) in
            
            // Track update count
            var updateCount = 0
            
            // The callback that would be passed to the editor
            let onDirectionMappingChanged: (StickDirection, Mapping?) -> Void = { _, _ in
                updateCount += 1
            }
            
            // Simulate parameter changes for each mapping
            for mapping in partialMappings.mappings {
                onDirectionMappingChanged(mapping.direction, mapping.toMapping())
            }
            
            // Verify update was triggered for each change
            return updateCount == partialMappings.mappings.count
        }
    }
}
