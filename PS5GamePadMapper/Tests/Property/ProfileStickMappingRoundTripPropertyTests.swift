import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Profile Stick Mapping serialization
/// **Feature: stick-interaction-enhancement, Property 11: Profile Stick Mapping Round-Trip**
final class ProfileStickMappingRoundTripPropertyTests: XCTestCase {
    
    // MARK: - Property 11: Profile Stick Mapping Round-Trip
    
    /// **Feature: stick-interaction-enhancement, Property 11: Profile Stick Mapping Round-Trip**
    /// **Validates: Requirements 8.1, 8.2, 8.4, 8.5**
    ///
    /// *For any* Profile containing stick mappings (both direction and mouse mode),
    /// serializing to JSON and deserializing should produce an equivalent Profile
    /// with all stick mapping configurations preserved.
    func testProfileStickMappingRoundTrip() {
        property("Profile with stick mappings serializes and deserializes correctly") <- forAll { (profile: Profile) in
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                // Serialize to JSON
                let jsonData = try encoder.encode(profile)
                
                // Deserialize back
                let decodedProfile = try decoder.decode(Profile.self, from: jsonData)
                
                // Verify all properties are preserved including stick mappings
                return decodedProfile.id == profile.id
                    && decodedProfile.name == profile.name
                    && decodedProfile.mappings == profile.mappings
                    && decodedProfile.macros == profile.macros
                    && decodedProfile.scripts == profile.scripts
                    && decodedProfile.applicationBindings == profile.applicationBindings
            } catch {
                return false
            }
        }
    }
    
    /// Test that InputSource.stick serializes correctly
    /// **Feature: stick-interaction-enhancement, Property 11: Profile Stick Mapping Round-Trip**
    /// **Validates: Requirements 8.1, 8.4**
    func testInputSourceStickSerializationRoundTrip() {
        property("InputSource.stick serializes and deserializes correctly") <- forAll { (stickType: StickType) in
            do {
                let inputSource = InputSource.stick(stickType)
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                // Serialize to JSON
                let jsonData = try encoder.encode(inputSource)
                
                // Deserialize back
                let decodedInputSource = try decoder.decode(InputSource.self, from: jsonData)
                
                // Verify the stick type is preserved
                if case .stick(let decodedStickType) = decodedInputSource {
                    return decodedStickType == stickType
                }
                return false
            } catch {
                return false
            }
        }
    }
    
    /// Test that profiles with stick-based direction mappings serialize correctly
    /// **Feature: stick-interaction-enhancement, Property 11: Profile Stick Mapping Round-Trip**
    /// **Validates: Requirements 8.2, 8.5**
    func testProfileWithDirectionMappingsRoundTrip() {
        property("Profile with direction mappings serializes correctly") <- forAll { (directionInput: DirectionInput, action: Action) in
            do {
                let mapping = Mapping(
                    input: .direction(directionInput),
                    trigger: .press,
                    action: action
                )
                
                let profile = Profile(
                    id: UUID(),
                    name: "TestProfile",
                    mappings: [mapping],
                    macros: [],
                    scripts: [],
                    applicationBindings: nil
                )
                
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                // Serialize to JSON
                let jsonData = try encoder.encode(profile)
                
                // Deserialize back
                let decodedProfile = try decoder.decode(Profile.self, from: jsonData)
                
                // Verify direction mappings are preserved
                guard decodedProfile.mappings.count == 1,
                      let decodedMapping = decodedProfile.mappings.first else {
                    return false
                }
                
                if case .direction(let decodedDirection) = decodedMapping.input {
                    return decodedDirection == directionInput
                        && decodedMapping.trigger == mapping.trigger
                        && decodedMapping.action == mapping.action
                }
                return false
            } catch {
                return false
            }
        }
    }
    
    /// Test that profiles with mouse mode mappings (axis-based) serialize correctly
    /// **Feature: stick-interaction-enhancement, Property 11: Profile Stick Mapping Round-Trip**
    /// **Validates: Requirements 8.2, 8.5**
    func testProfileWithMouseModeMappingsRoundTrip() {
        property("Profile with mouse mode mappings serializes correctly") <- forAll { (mouseConfig: MouseMoveAction) in
            do {
                // Create axis mappings for mouse mode (left stick X and Y)
                let mappingX = Mapping(
                    input: .axis(.leftStickX),
                    trigger: .press,
                    action: .mouseMove(mouseConfig)
                )
                let mappingY = Mapping(
                    input: .axis(.leftStickY),
                    trigger: .press,
                    action: .mouseMove(mouseConfig)
                )
                
                let profile = Profile(
                    id: UUID(),
                    name: "MouseModeProfile",
                    mappings: [mappingX, mappingY],
                    macros: [],
                    scripts: [],
                    applicationBindings: nil
                )
                
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                // Serialize to JSON
                let jsonData = try encoder.encode(profile)
                
                // Deserialize back
                let decodedProfile = try decoder.decode(Profile.self, from: jsonData)
                
                // Verify mouse mode mappings are preserved
                guard decodedProfile.mappings.count == 2 else {
                    return false
                }
                
                // Check that all mappings are preserved
                for originalMapping in profile.mappings {
                    let found = decodedProfile.mappings.contains { decodedMapping in
                        decodedMapping.input == originalMapping.input
                            && decodedMapping.trigger == originalMapping.trigger
                            && decodedMapping.action == originalMapping.action
                    }
                    if !found {
                        return false
                    }
                }
                
                return true
            } catch {
                return false
            }
        }
    }
}
