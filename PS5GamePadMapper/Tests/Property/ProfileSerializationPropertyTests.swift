import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Profile serialization
/// **Feature: ps5-gamepad-mapper, Property 15: Profile Serialization Round-Trip**
final class ProfileSerializationPropertyTests: XCTestCase {
    
    // MARK: - Property 15: Profile Serialization Round-Trip
    
    /// **Feature: ps5-gamepad-mapper, Property 15: Profile Serialization Round-Trip**
    /// **Validates: Requirements 13.6, 13.7**
    ///
    /// *For any* valid Profile object, serializing to JSON and then deserializing
    /// SHALL produce an equivalent Profile with identical mappings, macros, scripts, and settings.
    func testProfileSerializationRoundTrip() {
        property("Profile serialization round-trip preserves all data") <- forAll { (profile: Profile) in
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                // Serialize to JSON
                let jsonData = try encoder.encode(profile)
                
                // Deserialize back
                let decodedProfile = try decoder.decode(Profile.self, from: jsonData)
                
                // Verify all properties are preserved
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
    
    /// Additional property: JSON output is valid and parseable
    func testProfileSerializationProducesValidJSON() {
        property("Profile serialization produces valid JSON") <- forAll { (profile: Profile) in
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(profile)
                
                // Verify it's valid JSON by parsing with JSONSerialization
                let _ = try JSONSerialization.jsonObject(with: jsonData, options: [])
                return true
            } catch {
                return false
            }
        }
    }
}
