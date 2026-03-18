import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property tests for control flow parsing
/// **Feature: macro-script-enhancements, Property 5: Control Flow Parsing Round-Trip**
final class ControlFlowParsingPropertyTests: XCTestCase {
    
    var parser: ScriptParser!
    var printer: ScriptPrettyPrinter!
    
    override func setUp() {
        super.setUp()
        parser = ScriptParser()
        printer = ScriptPrettyPrinter()
    }
    
    // MARK: - Property 5: Control Flow Parsing Round-Trip
    
    /// **Feature: macro-script-enhancements, Property 5: Control Flow Parsing Round-Trip**
    /// **Validates: Requirements 2.1, 2.2, 3.1**
    /// For any valid script containing if/else and while statements, parsing the script
    /// and then pretty-printing the AST SHALL produce a semantically equivalent script.
    func testControlFlowParsingRoundTrip() {
        property("Parsing then printing produces parseable output") <- forAll { (statement: AnyStatement) in
            // Print the statement
            let printed = self.printer.print([statement])
            
            // Parse it back
            do {
                let parsed = try self.parser.parse(printed)
                
                // Should have exactly one statement
                guard parsed.count == 1 else {
                    return false
                }
                
                // The parsed statement should be equivalent
                return parsed[0] == statement
            } catch {
                // Parsing should not fail for valid statements
                print("Parse error: \(error)")
                return false
            }
        }
    }
    
    /// Test parsing simple function calls
    func testParseFunctionCall() {
        property("Function calls parse correctly") <- forAll { (funcCall: FunctionCallStatement) in
            let printed = self.printer.print([.functionCall(funcCall)])
            
            do {
                let parsed = try self.parser.parse(printed)
                guard parsed.count == 1,
                      case .functionCall(let parsedFunc) = parsed[0] else {
                    return false
                }
                
                return parsedFunc.name == funcCall.name
            } catch {
                return false
            }
        }
    }
    
    /// Test parsing if statements
    func testParseIfStatement() {
        let script = """
        if (isButtonPressed("X")) {
            pressKey("a")
        }
        """
        
        do {
            let parsed = try parser.parse(script)
            XCTAssertEqual(parsed.count, 1)
            
            guard case .ifStatement(let ifStmt) = parsed[0] else {
                XCTFail("Expected if statement")
                return
            }
            
            guard case .buttonPressed(let button) = ifStmt.condition else {
                XCTFail("Expected button pressed condition")
                return
            }
            
            XCTAssertEqual(button, "X")
            XCTAssertEqual(ifStmt.thenBlock.count, 1)
            XCTAssertNil(ifStmt.elseBlock)
        } catch {
            XCTFail("Parse error: \(error)")
        }
    }
    
    /// Test parsing if-else statements
    func testParseIfElseStatement() {
        let script = """
        if (isButtonPressed("X")) {
            pressKey("a")
        } else {
            pressKey("b")
        }
        """
        
        do {
            let parsed = try parser.parse(script)
            XCTAssertEqual(parsed.count, 1)
            
            guard case .ifStatement(let ifStmt) = parsed[0] else {
                XCTFail("Expected if statement")
                return
            }
            
            XCTAssertEqual(ifStmt.thenBlock.count, 1)
            XCTAssertNotNil(ifStmt.elseBlock)
            XCTAssertEqual(ifStmt.elseBlock?.count, 1)
        } catch {
            XCTFail("Parse error: \(error)")
        }
    }
    
    /// Test parsing while statements
    func testParseWhileStatement() {
        let script = """
        while (isButtonPressed("R1")) {
            pressKey("space")
            sleep(100)
        }
        """
        
        do {
            let parsed = try parser.parse(script)
            XCTAssertEqual(parsed.count, 1)
            
            guard case .whileStatement(let whileStmt) = parsed[0] else {
                XCTFail("Expected while statement")
                return
            }
            
            guard case .buttonPressed(let button) = whileStmt.condition else {
                XCTFail("Expected button pressed condition")
                return
            }
            
            XCTAssertEqual(button, "R1")
            XCTAssertEqual(whileStmt.body.count, 2)
        } catch {
            XCTFail("Parse error: \(error)")
        }
    }
    
    /// Test parsing break and continue statements
    func testParseBreakContinue() {
        let script = """
        while (true) {
            if (isButtonPressed("X")) {
                break
            }
            continue
        }
        """
        
        do {
            let parsed = try parser.parse(script)
            XCTAssertEqual(parsed.count, 1)
            
            guard case .whileStatement(let whileStmt) = parsed[0] else {
                XCTFail("Expected while statement")
                return
            }
            
            XCTAssertEqual(whileStmt.body.count, 2)
            
            // Check for break inside if
            guard case .ifStatement(let ifStmt) = whileStmt.body[0] else {
                XCTFail("Expected if statement")
                return
            }
            
            guard case .breakStatement = ifStmt.thenBlock[0] else {
                XCTFail("Expected break statement")
                return
            }
            
            // Check for continue
            guard case .continueStatement = whileStmt.body[1] else {
                XCTFail("Expected continue statement")
                return
            }
        } catch {
            XCTFail("Parse error: \(error)")
        }
    }
    
    /// Test parsing complex conditions
    func testParseComplexConditions() {
        let script = """
        if (isButtonPressed("X") && !isButtonPressed("O")) {
            pressKey("a")
        }
        """
        
        do {
            let parsed = try parser.parse(script)
            XCTAssertEqual(parsed.count, 1)
            
            guard case .ifStatement(let ifStmt) = parsed[0] else {
                XCTFail("Expected if statement")
                return
            }
            
            guard case .and(let left, let right) = ifStmt.condition else {
                XCTFail("Expected AND condition")
                return
            }
            
            guard case .buttonPressed(let button1) = left else {
                XCTFail("Expected button pressed on left")
                return
            }
            XCTAssertEqual(button1, "X")
            
            guard case .not(let inner) = right else {
                XCTFail("Expected NOT on right")
                return
            }
            
            guard case .buttonPressed(let button2) = inner else {
                XCTFail("Expected button pressed inside NOT")
                return
            }
            XCTAssertEqual(button2, "O")
        } catch {
            XCTFail("Parse error: \(error)")
        }
    }
    
    /// Test parsing comparison conditions
    func testParseComparisonConditions() {
        let script = """
        if (x > 10) {
            pressKey("a")
        }
        """
        
        do {
            let parsed = try parser.parse(script)
            XCTAssertEqual(parsed.count, 1)
            
            guard case .ifStatement(let ifStmt) = parsed[0] else {
                XCTFail("Expected if statement")
                return
            }
            
            guard case .intComparison(let left, let op, let right) = ifStmt.condition else {
                XCTFail("Expected int comparison")
                return
            }
            
            guard case .variable(let varName) = left else {
                XCTFail("Expected variable on left")
                return
            }
            XCTAssertEqual(varName, "x")
            XCTAssertEqual(op, .greaterThan)
            
            guard case .literal(let value) = right else {
                XCTFail("Expected literal on right")
                return
            }
            XCTAssertEqual(value, 10)
        } catch {
            XCTFail("Parse error: \(error)")
        }
    }
}
