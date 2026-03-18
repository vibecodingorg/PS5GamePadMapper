import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Profile Direction Mapping Serialization
/// **Feature: stick-direction-mapping, Property 7: Profile Direction Mapping Round-Trip**
final class ProfileDirectionMappingPropertyTests: XCTestCase {
    
    // MARK: - Property 7: Profile Direction Mapping Round-Trip
    
    /// **Feature: stick-direction-mapping, Property 7: Profile Direction Mapping Round-Trip**
    /// **Validates: Requirements 7.1, 7.2, 7.4, 7.5**
    ///
    /// *For any* Profile containing direction mappings, serializing to JSON and deserializing
    /// should produce an equivalent Profile with all direction mappings preserved, including
    /// stick type, direction, threshold, action, and trigger mode.
    func testProfileDirectionMappingRoundTrip() {
        // Generator for profiles that specifically contain direction mappings
        let profileWithDirectionMappingsGen = Gen.compose { c -> Profile in
            // Generate 1-3 direction mappings
            let directionMappingCount: Int = c.generate(using: Gen.fromElements(in: 1...3))
            
            var mappings: [Mapping] = []
            for _ in 0..<directionMappingCount {
                let dirInput: DirectionInput = c.generate()
                let trigger: TriggerMode = c.generate()
                let action: Action = c.generate()
                mappings.append(Mapping(input: .direction(dirInput), trigger: trigger, action: action))
            }
            
            // Optionally add some non-direction mappings
            let otherMappingCount: Int = c.generate(using: Gen.fromElements(in: 0...2))
            for _ in 0..<otherMappingCount {
                let buttonInput: ButtonType = c.generate()
                let trigger: TriggerMode = c.generate()
                let action: Action = c.generate()
                mappings.append(Mapping(input: .button(buttonInput), trigger: trigger, action: action))
            }
            
            return Profile(
                id: UUID(),
                name: c.generate(using: Gen.fromElements(of: ["DirectionProfile", "GameProfile", "TestProfile"])),
                mappings: mappings,
                macros: [],
                scripts: [],
                applicationBindings: nil
            )
        }
        
        property("Profile with direction mappings serialization round-trip preserves all data") <- forAll(profileWithDirectionMappingsGen) { profile in
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                // Serialize to JSON
                let jsonData = try encoder.encode(profile)
                
                // Deserialize back
                let decodedProfile = try decoder.decode(Profile.self, from: jsonData)
                
                // Verify basic profile properties
                guard decodedProfile.id == profile.id,
                      decodedProfile.name == profile.name,
                      decodedProfile.mappings.count == profile.mappings.count else {
                    return false
                }
                
                // Verify each mapping, especially direction mappings
                for (original, decoded) in zip(profile.mappings, decodedProfile.mappings) {
                    // Check input source
                    switch (original.input, decoded.input) {
                    case (.direction(let origDir), .direction(let decDir)):
                        // Verify direction mapping details (Requirements 7.4, 7.5)
                        guard origDir.stick == decDir.stick,
                              origDir.direction == decDir.direction,
                              abs(origDir.threshold - decDir.threshold) < 0.0001 else {
                            return false
                        }
                    case (.button(let origBtn), .button(let decBtn)):
                        guard origBtn == decBtn else { return false }
                    case (.axis(let origAxis), .axis(let decAxis)):
                        guard origAxis == decAxis else { return false }
                    default:
                        return false
                    }
                    
                    // Check trigger mode
                    guard original.trigger == decoded.trigger else { return false }
                    
                    // Check action
                    guard original.action == decoded.action else { return false }
                }
                
                return true
            } catch {
                return false
            }
        }
    }

    
    /// Test backward compatibility: profiles without direction mappings should still serialize correctly
    /// **Validates: Requirements 7.1, 7.2**
    func testProfileWithoutDirectionMappingsBackwardCompatibility() {
        // Generator for profiles without direction mappings (legacy profiles)
        let legacyProfileGen = Gen.compose { c -> Profile in
            let mappingCount: Int = c.generate(using: Gen.fromElements(in: 0...3))
            
            var mappings: [Mapping] = []
            for _ in 0..<mappingCount {
                // Only button and axis inputs (no direction)
                let useButton: Bool = c.generate()
                let input: InputSource
                if useButton {
                    input = .button(c.generate())
                } else {
                    input = .axis(c.generate())
                }
                let trigger: TriggerMode = c.generate()
                let action: Action = c.generate()
                mappings.append(Mapping(input: input, trigger: trigger, action: action))
            }
            
            return Profile(
                id: UUID(),
                name: c.generate(using: Gen.fromElements(of: ["LegacyProfile", "OldProfile", "Classic"])),
                mappings: mappings,
                macros: [],
                scripts: [],
                applicationBindings: nil
            )
        }
        
        property("Legacy profiles without direction mappings serialize correctly") <- forAll(legacyProfileGen) { profile in
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                // Serialize to JSON
                let jsonData = try encoder.encode(profile)
                
                // Deserialize back
                let decodedProfile = try decoder.decode(Profile.self, from: jsonData)
                
                // Verify all properties preserved
                return decodedProfile.id == profile.id
                    && decodedProfile.name == profile.name
                    && decodedProfile.mappings == profile.mappings
            } catch {
                return false
            }
        }
    }
    
    /// Test mixed profiles: profiles with both direction and non-direction mappings
    /// **Validates: Requirements 7.1, 7.2, 7.4, 7.5**
    func testMixedProfileSerialization() {
        // Generator for profiles with mixed mapping types
        let mixedProfileGen = Gen.compose { c -> Profile in
            var mappings: [Mapping] = []
            
            // Add at least one direction mapping
            let dirInput: DirectionInput = c.generate()
            let dirTrigger: TriggerMode = c.generate()
            let dirAction: Action = c.generate()
            mappings.append(Mapping(input: .direction(dirInput), trigger: dirTrigger, action: dirAction))
            
            // Add at least one button mapping
            let btnInput: ButtonType = c.generate()
            let btnTrigger: TriggerMode = c.generate()
            let btnAction: Action = c.generate()
            mappings.append(Mapping(input: .button(btnInput), trigger: btnTrigger, action: btnAction))
            
            // Add at least one axis mapping
            let axisInput: AxisType = c.generate()
            let axisTrigger: TriggerMode = c.generate()
            let axisAction: Action = c.generate()
            mappings.append(Mapping(input: .axis(axisInput), trigger: axisTrigger, action: axisAction))
            
            return Profile(
                id: UUID(),
                name: c.generate(using: Gen.fromElements(of: ["MixedProfile", "HybridProfile", "CompleteProfile"])),
                mappings: mappings,
                macros: [],
                scripts: [],
                applicationBindings: nil
            )
        }
        
        property("Mixed profiles with all input types serialize correctly") <- forAll(mixedProfileGen) { profile in
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                // Serialize to JSON
                let jsonData = try encoder.encode(profile)
                
                // Deserialize back
                let decodedProfile = try decoder.decode(Profile.self, from: jsonData)
                
                // Verify all properties preserved
                guard decodedProfile.id == profile.id,
                      decodedProfile.name == profile.name,
                      decodedProfile.mappings.count == profile.mappings.count else {
                    return false
                }
                
                // Verify each mapping type is preserved
                var hasDirection = false
                var hasButton = false
                var hasAxis = false
                
                for (original, decoded) in zip(profile.mappings, decodedProfile.mappings) {
                    guard original.input == decoded.input,
                          original.trigger == decoded.trigger,
                          original.action == decoded.action else {
                        return false
                    }
                    
                    switch decoded.input {
                    case .direction: hasDirection = true
                    case .button: hasButton = true
                    case .axis: hasAxis = true
                    case .stick: break  // Stick is for UI selection only
                    }
                }
                
                // Ensure all types are present
                return hasDirection && hasButton && hasAxis
            } catch {
                return false
            }
        }
    }
    
    /// Test that direction mapping threshold is preserved exactly
    /// **Validates: Requirements 7.4, 7.5**
    func testDirectionMappingThresholdPreservation() {
        // Generator for specific threshold values
        let thresholdGen = Gen.fromElements(of: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9])
        
        let directionMappingGen = Gen.zip(
            StickType.arbitrary,
            StickDirection.arbitrary,
            thresholdGen,
            TriggerMode.arbitrary,
            Action.arbitrary
        ).map { (stick, direction, threshold, trigger, action) -> Mapping in
            let dirInput = DirectionInput(stick: stick, direction: direction, threshold: threshold)
            return Mapping(input: .direction(dirInput), trigger: trigger, action: action)
        }
        
        property("Direction mapping threshold is preserved exactly") <- forAll(directionMappingGen) { mapping in
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                // Serialize to JSON
                let jsonData = try encoder.encode(mapping)
                
                // Deserialize back
                let decodedMapping = try decoder.decode(Mapping.self, from: jsonData)
                
                // Extract direction inputs
                guard case .direction(let origDir) = mapping.input,
                      case .direction(let decDir) = decodedMapping.input else {
                    return false
                }
                
                // Verify threshold is preserved exactly
                return abs(origDir.threshold - decDir.threshold) < 0.0001
            } catch {
                return false
            }
        }
    }
    
    /// Test all 8 directions serialize correctly
    /// **Validates: Requirements 7.4, 7.5**
    func testAllDirectionsSerializeCorrectly() {
        property("All 8 stick directions serialize correctly") <- forAll { (stick: StickType, trigger: TriggerMode, action: Action) in
            // Test all 8 directions
            for direction in StickDirection.allCases {
                let dirInput = DirectionInput(stick: stick, direction: direction, threshold: 0.5)
                let mapping = Mapping(input: .direction(dirInput), trigger: trigger, action: action)
                
                do {
                    let encoder = JSONEncoder()
                    let decoder = JSONDecoder()
                    
                    let jsonData = try encoder.encode(mapping)
                    let decodedMapping = try decoder.decode(Mapping.self, from: jsonData)
                    
                    guard case .direction(let decDir) = decodedMapping.input else {
                        return false
                    }
                    
                    guard decDir.direction == direction else {
                        return false
                    }
                } catch {
                    return false
                }
            }
            return true
        }
    }
}
