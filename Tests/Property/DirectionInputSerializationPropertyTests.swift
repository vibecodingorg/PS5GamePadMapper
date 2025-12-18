import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Direction Input Serialization
/// **Feature: stick-direction-mapping, Property 1: Direction Input Serialization Round-Trip**
final class DirectionInputSerializationPropertyTests: XCTestCase {
    
    // MARK: - Property 1: Direction Input Serialization Round-Trip
    
    /// **Feature: stick-direction-mapping, Property 1: Direction Input Serialization Round-Trip**
    /// **Validates: Requirements 1.6, 1.7**
    ///
    /// *For any* valid DirectionInput, serializing to JSON and deserializing should produce
    /// an equivalent DirectionInput with the same stick, direction, and threshold values.
    func testDirectionInputSerializationRoundTrip() {
        property("DirectionInput serialization round-trip preserves all data") <- forAll { (input: DirectionInput) in
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                // Serialize to JSON
                let jsonData = try encoder.encode(input)
                
                // Deserialize back
                let decodedInput = try decoder.decode(DirectionInput.self, from: jsonData)
                
                // Verify all properties are preserved
                return decodedInput.stick == input.stick
                    && decodedInput.direction == input.direction
                    && abs(decodedInput.threshold - input.threshold) < 0.0001
            } catch {
                return false
            }
        }
    }
    
    /// Additional property: JSON output is valid and parseable
    func testDirectionInputSerializationProducesValidJSON() {
        property("DirectionInput serialization produces valid JSON") <- forAll { (input: DirectionInput) in
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(input)
                
                // Verify it's valid JSON by parsing with JSONSerialization
                let _ = try JSONSerialization.jsonObject(with: jsonData, options: [])
                return true
            } catch {
                return false
            }
        }
    }
    
    /// Additional property: StickType serialization round-trip
    func testStickTypeSerializationRoundTrip() {
        property("StickType serialization round-trip preserves value") <- forAll { (stickType: StickType) in
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                let jsonData = try encoder.encode(stickType)
                let decoded = try decoder.decode(StickType.self, from: jsonData)
                
                return decoded == stickType
            } catch {
                return false
            }
        }
    }
    
    /// Additional property: StickDirection serialization round-trip
    func testStickDirectionSerializationRoundTrip() {
        property("StickDirection serialization round-trip preserves value") <- forAll { (direction: StickDirection) in
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                let jsonData = try encoder.encode(direction)
                let decoded = try decoder.decode(StickDirection.self, from: jsonData)
                
                return decoded == direction
            } catch {
                return false
            }
        }
    }
    
    /// Additional property: InputSource.direction serialization round-trip
    func testInputSourceDirectionSerializationRoundTrip() {
        property("InputSource.direction serialization round-trip preserves data") <- forAll { (dirInput: DirectionInput) in
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                let inputSource = InputSource.direction(dirInput)
                let jsonData = try encoder.encode(inputSource)
                let decoded = try decoder.decode(InputSource.self, from: jsonData)
                
                if case .direction(let decodedDir) = decoded {
                    return decodedDir.stick == dirInput.stick
                        && decodedDir.direction == dirInput.direction
                        && abs(decodedDir.threshold - dirInput.threshold) < 0.0001
                }
                return false
            } catch {
                return false
            }
        }
    }
}
