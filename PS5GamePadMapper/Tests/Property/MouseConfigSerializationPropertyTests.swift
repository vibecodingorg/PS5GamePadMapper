import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for mouse configuration serialization
/// **Feature: stick-interaction-enhancement, Property 6: Mouse Config Serialization Round-Trip**
final class MouseConfigSerializationPropertyTests: XCTestCase {
    
    // MARK: - Property 6: Mouse Config Serialization Round-Trip
    
    /// **Feature: stick-interaction-enhancement, Property 6: Mouse Config Serialization Round-Trip**
    /// **Validates: Requirements 4.7, 4.8**
    ///
    /// *For any* valid StickMouseConfig (MouseMoveAction), serializing to JSON and deserializing
    /// should produce an equivalent configuration with the same sensitivity, deadzone, and curve parameters.
    func testMouseConfigSerializationRoundTrip() {
        property("Mouse config serializes and deserializes correctly") <- forAll { (config: MouseMoveAction) in
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                // Serialize to JSON
                let jsonData = try encoder.encode(config)
                
                // Deserialize back
                let decodedConfig = try decoder.decode(MouseMoveAction.self, from: jsonData)
                
                // Verify all properties are preserved
                return decodedConfig.sensitivity == config.sensitivity
                    && decodedConfig.deadzone == config.deadzone
                    && decodedConfig.curve == config.curve
            } catch {
                return false
            }
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 6: Mouse Config Serialization Round-Trip**
    /// **Validates: Requirements 4.7, 4.8**
    ///
    /// Test that JSON output is valid and parseable
    func testMouseConfigSerializationProducesValidJSON() {
        property("Mouse config serialization produces valid JSON") <- forAll { (config: MouseMoveAction) in
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(config)
                
                // Verify it's valid JSON by parsing with JSONSerialization
                let _ = try JSONSerialization.jsonObject(with: jsonData, options: [])
                return true
            } catch {
                return false
            }
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 6: Mouse Config Serialization Round-Trip**
    /// **Validates: Requirements 4.7, 4.8**
    ///
    /// Test that linear curve serializes correctly
    func testLinearCurveSerializationRoundTrip() {
        property("Linear curve serializes and deserializes correctly") <- forAll { (sensitivity: Double, deadzone: Double) in
            let validSensitivity = max(0.1, min(10.0, sensitivity))
            let validDeadzone = max(0.0, min(0.5, deadzone))
            
            let config = MouseMoveAction(sensitivity: validSensitivity, deadzone: validDeadzone, curve: .linear)
            
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                let jsonData = try encoder.encode(config)
                let decodedConfig = try decoder.decode(MouseMoveAction.self, from: jsonData)
                
                if case .linear = decodedConfig.curve {
                    return true
                }
                return false
            } catch {
                return false
            }
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 6: Mouse Config Serialization Round-Trip**
    /// **Validates: Requirements 4.7, 4.8**
    ///
    /// Test that exponential curve with power serializes correctly
    func testExponentialCurveSerializationRoundTrip() {
        property("Exponential curve serializes and deserializes correctly") <- forAll { (sensitivity: Double, deadzone: Double, power: Double) in
            let validSensitivity = max(0.1, min(10.0, sensitivity))
            let validDeadzone = max(0.0, min(0.5, deadzone))
            let validPower = max(1.0, min(4.0, power))
            
            let config = MouseMoveAction(sensitivity: validSensitivity, deadzone: validDeadzone, curve: .exponential(power: validPower))
            
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                let jsonData = try encoder.encode(config)
                let decodedConfig = try decoder.decode(MouseMoveAction.self, from: jsonData)
                
                if case .exponential(let decodedPower) = decodedConfig.curve {
                    return abs(decodedPower - validPower) < 0.0001
                }
                return false
            } catch {
                return false
            }
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 6: Mouse Config Serialization Round-Trip**
    /// **Validates: Requirements 4.7, 4.8**
    ///
    /// Test that mouse config embedded in a Mapping serializes correctly
    func testMouseConfigInMappingSerializationRoundTrip() {
        property("Mouse config in Mapping serializes and deserializes correctly") <- forAll { (config: MouseMoveAction) in
            let mapping = Mapping(
                input: .axis(.leftStickX),
                trigger: .press,
                action: .mouseMove(config)
            )
            
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                let jsonData = try encoder.encode(mapping)
                let decodedMapping = try decoder.decode(Mapping.self, from: jsonData)
                
                if case .mouseMove(let decodedConfig) = decodedMapping.action {
                    return decodedConfig.sensitivity == config.sensitivity
                        && decodedConfig.deadzone == config.deadzone
                        && decodedConfig.curve == config.curve
                }
                return false
            } catch {
                return false
            }
        }
    }
    
    /// **Feature: stick-interaction-enhancement, Property 6: Mouse Config Serialization Round-Trip**
    /// **Validates: Requirements 4.7, 4.8**
    ///
    /// Test that mouse config embedded in a Profile serializes correctly
    func testMouseConfigInProfileSerializationRoundTrip() {
        property("Mouse config in Profile serializes and deserializes correctly") <- forAll { (config: MouseMoveAction) in
            let mapping = Mapping(
                input: .axis(.rightStickX),
                trigger: .press,
                action: .mouseMove(config)
            )
            
            let profile = Profile(
                id: UUID(),
                name: "TestProfile",
                mappings: [mapping],
                macros: [],
                scripts: [],
                applicationBindings: nil
            )
            
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                let jsonData = try encoder.encode(profile)
                let decodedProfile = try decoder.decode(Profile.self, from: jsonData)
                
                guard let decodedMapping = decodedProfile.mappings.first,
                      case .mouseMove(let decodedConfig) = decodedMapping.action else {
                    return false
                }
                
                return decodedConfig.sensitivity == config.sensitivity
                    && decodedConfig.deadzone == config.deadzone
                    && decodedConfig.curve == config.curve
            } catch {
                return false
            }
        }
    }
}
