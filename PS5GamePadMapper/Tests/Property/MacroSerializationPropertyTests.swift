import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Macro serialization
/// **Feature: ps5-gamepad-mapper, Property 7: Macro Serialization Round-Trip**
final class MacroSerializationPropertyTests: XCTestCase {
    
    // MARK: - Property 7: Macro Serialization Round-Trip
    
    /// **Feature: ps5-gamepad-mapper, Property 7: Macro Serialization Round-Trip**
    /// **Validates: Requirements 8.5, 8.6**
    ///
    /// *For any* valid Macro object, serializing to JSON and then deserializing
    /// SHALL produce an equivalent Macro with identical steps, delays, and configuration.
    func testMacroSerializationRoundTrip() {
        property("Macro serialization round-trip preserves all data") <- forAll { (macro: Macro) in
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                // Serialize to JSON
                let jsonData = try encoder.encode(macro)
                
                // Deserialize back
                let decodedMacro = try decoder.decode(Macro.self, from: jsonData)
                
                // Verify all properties are preserved
                // Note: We compare by value, not by reference
                return decodedMacro.id == macro.id
                    && decodedMacro.name == macro.name
                    && decodedMacro.steps == macro.steps
                    && decodedMacro.type == macro.type
            } catch {
                return false
            }
        }
    }
    
    /// Additional property: JSON output is valid and parseable
    func testMacroSerializationProducesValidJSON() {
        property("Macro serialization produces valid JSON") <- forAll { (macro: Macro) in
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(macro)
                
                // Verify it's valid JSON by parsing with JSONSerialization
                let _ = try JSONSerialization.jsonObject(with: jsonData, options: [])
                return true
            } catch {
                return false
            }
        }
    }
}
