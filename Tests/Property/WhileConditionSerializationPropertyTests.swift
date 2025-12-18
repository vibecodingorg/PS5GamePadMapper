import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for WhileCondition macro serialization
/// **Feature: macro-script-enhancements, Property 13: WhileCondition Macro Serialization Round-Trip**
final class WhileConditionSerializationPropertyTests: XCTestCase {
    
    // MARK: - Generators
    
    /// Generator for valid condition strings
    static var conditionStringGen: Gen<String> {
        Gen.fromElements(of: [
            "isButtonPressed(\"cross\")",
            "isButtonPressed(\"circle\")",
            "isButtonPressed(\"square\")",
            "isButtonPressed(\"triangle\")",
            "isButtonPressed(\"L1\")",
            "isButtonPressed(\"R1\")",
            "isButtonPressed(\"L2\")",
            "isButtonPressed(\"R2\")",
            "true",
            "false",
            "isButtonPressed(\"cross\") && isButtonPressed(\"circle\")",
            "isButtonPressed(\"L1\") || isButtonPressed(\"R1\")",
            "!isButtonPressed(\"cross\")"
        ])
    }
    
    /// Generator for whileCondition macros
    static var whileConditionMacroGen: Gen<Macro> {
        Gen.compose { c in
            let condition: String = c.generate(using: conditionStringGen)
            let stepCount: Int = c.generate(using: Gen.fromElements(in: 1...5))
            var steps: [MacroStep] = []
            for _ in 0..<stepCount {
                steps.append(c.generate())
            }
            
            return Macro(
                id: UUID(),
                name: c.generate(using: Gen.fromElements(of: ["WhileMacro", "ConditionMacro", "LoopMacro"])),
                steps: steps,
                type: .whileCondition(condition: condition)
            )
        }
    }
    
    // MARK: - Property 13: WhileCondition Macro Serialization Round-Trip
    
    /// **Feature: macro-script-enhancements, Property 13: WhileCondition Macro Serialization Round-Trip**
    /// **Validates: Requirements 4.6**
    ///
    /// *For any* valid whileCondition macro, serializing to JSON and deserializing
    /// SHALL produce an equivalent macro with the same condition expression.
    func testWhileConditionMacroSerializationRoundTrip() {
        property("WhileCondition macro serialization round-trip preserves condition") <- forAll(
            WhileConditionSerializationPropertyTests.whileConditionMacroGen
        ) { (macro: Macro) in
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                // Serialize to JSON
                let jsonData = try encoder.encode(macro)
                
                // Deserialize back
                let decodedMacro = try decoder.decode(Macro.self, from: jsonData)
                
                // Verify all properties are preserved
                guard decodedMacro.id == macro.id else { return false }
                guard decodedMacro.name == macro.name else { return false }
                guard decodedMacro.steps == macro.steps else { return false }
                
                // Verify the whileCondition type and condition are preserved
                guard case .whileCondition(let originalCondition) = macro.type,
                      case .whileCondition(let decodedCondition) = decodedMacro.type else {
                    return false
                }
                
                return originalCondition == decodedCondition
            } catch {
                return false
            }
        }
    }
    
    /// Test that whileCondition macro produces valid JSON
    /// **Validates: Requirements 4.6**
    func testWhileConditionMacroProducesValidJSON() {
        property("WhileCondition macro produces valid JSON") <- forAll(
            WhileConditionSerializationPropertyTests.whileConditionMacroGen
        ) { (macro: Macro) in
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(macro)
                
                // Verify it's valid JSON
                let _ = try JSONSerialization.jsonObject(with: jsonData, options: [])
                return true
            } catch {
                return false
            }
        }
    }
    
    /// Test that condition string is preserved exactly
    /// **Validates: Requirements 4.6**
    func testConditionStringPreservedExactly() {
        let conditions = [
            "isButtonPressed(\"cross\")",
            "isButtonPressed(\"circle\") && isButtonPressed(\"square\")",
            "!isButtonPressed(\"L1\")",
            "true",
            "false"
        ]
        
        for condition in conditions {
            let macro = Macro(
                name: "Test",
                steps: [.keyDown(keyCode: 1)],
                type: .whileCondition(condition: condition)
            )
            
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                let jsonData = try encoder.encode(macro)
                let decodedMacro = try decoder.decode(Macro.self, from: jsonData)
                
                guard case .whileCondition(let decodedCondition) = decodedMacro.type else {
                    XCTFail("Decoded macro should be whileCondition type")
                    return
                }
                
                XCTAssertEqual(decodedCondition, condition,
                              "Condition '\(condition)' should be preserved exactly")
            } catch {
                XCTFail("Serialization failed for condition: \(condition), error: \(error)")
            }
        }
    }
    
    /// Test that whileCondition can be distinguished from other macro types after deserialization
    /// **Validates: Requirements 4.6**
    func testWhileConditionTypeDistinguishable() {
        property("WhileCondition type is distinguishable after deserialization") <- forAll(
            WhileConditionSerializationPropertyTests.conditionStringGen
        ) { (condition: String) in
            let macro = Macro(
                name: "Test",
                steps: [.keyDown(keyCode: 1)],
                type: .whileCondition(condition: condition)
            )
            
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                let jsonData = try encoder.encode(macro)
                let decodedMacro = try decoder.decode(Macro.self, from: jsonData)
                
                // Verify it's specifically a whileCondition type
                if case .whileCondition = decodedMacro.type {
                    return true
                }
                return false
            } catch {
                return false
            }
        }
    }
    
    /// Test serialization with special characters in condition
    func testSerializationWithSpecialCharacters() {
        let specialConditions = [
            "isButtonPressed(\"cross\")",
            "isButtonPressed('circle')",
            "isButtonPressed(\"L1\") && isButtonPressed(\"R1\")",
            "isButtonPressed(\"square\") || isButtonPressed(\"triangle\")"
        ]
        
        for condition in specialConditions {
            let macro = Macro(
                name: "SpecialTest",
                steps: [.delay(milliseconds: 100)],
                type: .whileCondition(condition: condition)
            )
            
            do {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                
                let jsonData = try encoder.encode(macro)
                let decodedMacro = try decoder.decode(Macro.self, from: jsonData)
                
                guard case .whileCondition(let decodedCondition) = decodedMacro.type else {
                    XCTFail("Should decode as whileCondition")
                    return
                }
                
                XCTAssertEqual(decodedCondition, condition)
            } catch {
                XCTFail("Failed for condition: \(condition), error: \(error)")
            }
        }
    }
}
