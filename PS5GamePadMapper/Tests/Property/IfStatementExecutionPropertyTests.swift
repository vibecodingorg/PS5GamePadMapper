import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property tests for if statement execution
/// **Feature: macro-script-enhancements, Property 7: If Statement Execution**
final class IfStatementExecutionPropertyTests: XCTestCase {
    
    var scriptEngine: ScriptEngine!
    var mockContext: MockScriptContext!
    
    override func setUp() {
        super.setUp()
        scriptEngine = ScriptEngine()
        mockContext = MockScriptContext()
    }
    
    override func tearDown() {
        mockContext.reset()
        super.tearDown()
    }
    
    // MARK: - Property 7: If Statement Execution
    
    /// **Feature: macro-script-enhancements, Property 7: If Statement Execution**
    /// **Validates: Requirements 2.6, 2.7**
    /// For any if statement with a condition:
    /// - When condition is true, exactly the then-block statements SHALL execute
    /// - When condition is false and else-block exists, exactly the else-block statements SHALL execute
    /// - When condition is false and no else-block, no statements SHALL execute
    func testIfStatementExecutionWithTrueCondition() {
        // Property: When condition is true, then-block executes
        property("If condition true executes then-block") <- forAll(
            Gen<String>.fromElements(of: ["a", "b", "c", "d", "e"])
        ) { (key: String) in
            self.mockContext.reset()
            
            // Create if statement with true condition
            let ifStmt = IfStatement(
                condition: .boolLiteral(true),
                thenBlock: [.functionCall(FunctionCallStatement(name: "pressKey", arguments: [key]))],
                elseBlock: [.functionCall(FunctionCallStatement(name: "pressKey", arguments: ["z"]))]
            )
            
            // Execute
            let expectation = XCTestExpectation(description: "Execute if statement")
            Task {
                _ = try? await self.scriptEngine.executeStatement(.ifStatement(ifStmt), context: self.mockContext)
                expectation.fulfill()
            }
            
            // Wait for execution
            let result = XCTWaiter.wait(for: [expectation], timeout: 1.0)
            guard result == .completed else { return false }
            
            // Verify then-block executed (key pressed) and else-block did not (z not pressed)
            return self.mockContext.keyPresses.contains(key) && !self.mockContext.keyPresses.contains("z")
        }
    }
    
    func testIfStatementExecutionWithFalseConditionAndElse() {
        // Property: When condition is false and else exists, else-block executes
        property("If condition false with else executes else-block") <- forAll(
            Gen<String>.fromElements(of: ["a", "b", "c", "d", "e"])
        ) { (key: String) in
            self.mockContext.reset()
            
            // Create if statement with false condition and else block
            let ifStmt = IfStatement(
                condition: .boolLiteral(false),
                thenBlock: [.functionCall(FunctionCallStatement(name: "pressKey", arguments: ["z"]))],
                elseBlock: [.functionCall(FunctionCallStatement(name: "pressKey", arguments: [key]))]
            )
            
            // Execute
            let expectation = XCTestExpectation(description: "Execute if statement")
            Task {
                _ = try? await self.scriptEngine.executeStatement(.ifStatement(ifStmt), context: self.mockContext)
                expectation.fulfill()
            }
            
            // Wait for execution
            let result = XCTWaiter.wait(for: [expectation], timeout: 1.0)
            guard result == .completed else { return false }
            
            // Verify else-block executed (key pressed) and then-block did not (z not pressed)
            return self.mockContext.keyPresses.contains(key) && !self.mockContext.keyPresses.contains("z")
        }
    }
    
    func testIfStatementExecutionWithFalseConditionNoElse() {
        // Property: When condition is false and no else, nothing executes
        property("If condition false without else executes nothing") <- forAll(
            Gen<String>.fromElements(of: ["a", "b", "c", "d", "e"])
        ) { (key: String) in
            self.mockContext.reset()
            
            // Create if statement with false condition and no else block
            let ifStmt = IfStatement(
                condition: .boolLiteral(false),
                thenBlock: [.functionCall(FunctionCallStatement(name: "pressKey", arguments: [key]))],
                elseBlock: nil
            )
            
            // Execute
            let expectation = XCTestExpectation(description: "Execute if statement")
            Task {
                _ = try? await self.scriptEngine.executeStatement(.ifStatement(ifStmt), context: self.mockContext)
                expectation.fulfill()
            }
            
            // Wait for execution
            let result = XCTWaiter.wait(for: [expectation], timeout: 1.0)
            guard result == .completed else { return false }
            
            // Verify nothing executed
            return self.mockContext.keyPresses.isEmpty
        }
    }
    
    /// Test if statement with button state condition
    func testIfStatementWithButtonCondition() {
        property("If with button condition respects button state") <- forAll(
            Gen<String>.fromElements(of: ["X", "O", "Square", "Triangle"]),
            Bool.arbitrary
        ) { (button: String, isPressed: Bool) in
            self.mockContext.reset()
            self.mockContext.buttonStates[button] = isPressed
            
            // Create if statement with button pressed condition
            let ifStmt = IfStatement(
                condition: .buttonPressed(button: button),
                thenBlock: [.functionCall(FunctionCallStatement(name: "pressKey", arguments: ["a"]))],
                elseBlock: [.functionCall(FunctionCallStatement(name: "pressKey", arguments: ["b"]))]
            )
            
            // Execute
            let expectation = XCTestExpectation(description: "Execute if statement")
            Task {
                _ = try? await self.scriptEngine.executeStatement(.ifStatement(ifStmt), context: self.mockContext)
                expectation.fulfill()
            }
            
            // Wait for execution
            let result = XCTWaiter.wait(for: [expectation], timeout: 1.0)
            guard result == .completed else { return false }
            
            // Verify correct block executed based on button state
            if isPressed {
                return self.mockContext.keyPresses.contains("a") && !self.mockContext.keyPresses.contains("b")
            } else {
                return self.mockContext.keyPresses.contains("b") && !self.mockContext.keyPresses.contains("a")
            }
        }
    }
    
    /// Test multiple statements in then/else blocks
    func testIfStatementMultipleStatements() {
        property("If executes all statements in selected block") <- forAll(
            Bool.arbitrary,
            Gen<Int>.fromElements(in: 1...3)
        ) { (conditionValue: Bool, statementCount: Int) in
            self.mockContext.reset()
            
            // Create then-block with multiple statements
            var thenBlock: [AnyStatement] = []
            for i in 0..<statementCount {
                thenBlock.append(.functionCall(FunctionCallStatement(name: "pressKey", arguments: ["then\(i)"])))
            }
            
            // Create else-block with multiple statements
            var elseBlock: [AnyStatement] = []
            for i in 0..<statementCount {
                elseBlock.append(.functionCall(FunctionCallStatement(name: "pressKey", arguments: ["else\(i)"])))
            }
            
            let ifStmt = IfStatement(
                condition: .boolLiteral(conditionValue),
                thenBlock: thenBlock,
                elseBlock: elseBlock
            )
            
            // Execute
            let expectation = XCTestExpectation(description: "Execute if statement")
            Task {
                _ = try? await self.scriptEngine.executeStatement(.ifStatement(ifStmt), context: self.mockContext)
                expectation.fulfill()
            }
            
            // Wait for execution
            let result = XCTWaiter.wait(for: [expectation], timeout: 1.0)
            guard result == .completed else { return false }
            
            // Verify correct number of statements executed
            if conditionValue {
                // All then statements should have executed
                for i in 0..<statementCount {
                    if !self.mockContext.keyPresses.contains("then\(i)") {
                        return false
                    }
                }
                // No else statements should have executed
                for i in 0..<statementCount {
                    if self.mockContext.keyPresses.contains("else\(i)") {
                        return false
                    }
                }
            } else {
                // All else statements should have executed
                for i in 0..<statementCount {
                    if !self.mockContext.keyPresses.contains("else\(i)") {
                        return false
                    }
                }
                // No then statements should have executed
                for i in 0..<statementCount {
                    if self.mockContext.keyPresses.contains("then\(i)") {
                        return false
                    }
                }
            }
            
            return true
        }
    }
    
    /// Test nested if statements
    func testNestedIfStatements() {
        mockContext.reset()
        
        // Create nested if: if (true) { if (true) { pressKey("a") } }
        let innerIf = IfStatement(
            condition: .boolLiteral(true),
            thenBlock: [.functionCall(FunctionCallStatement(name: "pressKey", arguments: ["a"]))],
            elseBlock: nil
        )
        
        let outerIf = IfStatement(
            condition: .boolLiteral(true),
            thenBlock: [.ifStatement(innerIf)],
            elseBlock: nil
        )
        
        let expectation = XCTestExpectation(description: "Execute nested if")
        Task {
            _ = try? await self.scriptEngine.executeStatement(.ifStatement(outerIf), context: self.mockContext)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(mockContext.keyPresses.contains("a"))
    }
    
    /// Test if statement returns correct execution control
    func testIfStatementExecutionControl() {
        // Test that break in if statement propagates correctly
        let ifWithBreak = IfStatement(
            condition: .boolLiteral(true),
            thenBlock: [.breakStatement(BreakStatement())],
            elseBlock: nil
        )
        
        let expectation = XCTestExpectation(description: "Execute if with break")
        var executionControl: ExecutionControl = .normal
        
        Task {
            executionControl = try await self.scriptEngine.executeStatement(.ifStatement(ifWithBreak), context: self.mockContext)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(executionControl, .breakLoop)
    }
    
    /// Test if statement with complex condition
    func testIfStatementWithComplexCondition() {
        mockContext.reset()
        mockContext.buttonStates["X"] = true
        mockContext.buttonStates["O"] = false
        
        // if (isButtonPressed("X") && !isButtonPressed("O")) { pressKey("a") }
        let condition = ConditionExpression.and(
            .buttonPressed(button: "X"),
            .not(.buttonPressed(button: "O"))
        )
        
        let ifStmt = IfStatement(
            condition: condition,
            thenBlock: [.functionCall(FunctionCallStatement(name: "pressKey", arguments: ["a"]))],
            elseBlock: [.functionCall(FunctionCallStatement(name: "pressKey", arguments: ["b"]))]
        )
        
        let expectation = XCTestExpectation(description: "Execute if with complex condition")
        Task {
            _ = try? await self.scriptEngine.executeStatement(.ifStatement(ifStmt), context: self.mockContext)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // X is pressed and O is not pressed, so condition is true
        XCTAssertTrue(mockContext.keyPresses.contains("a"))
        XCTAssertFalse(mockContext.keyPresses.contains("b"))
    }
}
