import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property tests for break statement behavior
/// **Feature: macro-script-enhancements, Property 9: Break Statement Behavior**
final class BreakStatementPropertyTests: XCTestCase {
    
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
    
    // MARK: - Property 9: Break Statement Behavior
    
    /// **Feature: macro-script-enhancements, Property 9: Break Statement Behavior**
    /// **Validates: Requirements 3.5**
    /// For any while loop containing a break statement, when break is reached,
    /// the loop SHALL exit immediately without completing the current iteration
    /// or checking the condition again.
    func testBreakExitsLoopImmediately() {
        // Property: Break exits loop immediately, statements after break don't execute
        property("Break exits loop immediately") <- forAll(
            Gen<Int>.fromElements(in: 1...5),
            Gen<Int>.fromElements(in: 0...4)
        ) { (totalStatements: Int, breakPosition: Int) in
            self.mockContext.reset()
            
            // Ensure breakPosition is valid
            let validBreakPosition = min(breakPosition, totalStatements - 1)
            
            // Create body with statements before break, break, and statements after
            var body: [AnyStatement] = []
            
            // Add statements before break
            for i in 0..<validBreakPosition {
                body.append(.functionCall(FunctionCallStatement(name: "pressKey", arguments: ["before\(i)"])))
            }
            
            // Add break statement
            body.append(.breakStatement(BreakStatement()))
            
            // Add statements after break (should not execute)
            for i in validBreakPosition..<totalStatements {
                body.append(.functionCall(FunctionCallStatement(name: "pressKey", arguments: ["after\(i)"])))
            }
            
            // Create while loop with always-true condition
            let whileStmt = WhileStatement(
                condition: .boolLiteral(true),
                body: body
            )
            
            // Execute
            let expectation = XCTestExpectation(description: "Execute while with break")
            Task {
                _ = try? await self.scriptEngine.executeStatement(.whileStatement(whileStmt), context: self.mockContext)
                expectation.fulfill()
            }
            
            let result = XCTWaiter.wait(for: [expectation], timeout: 2.0)
            guard result == .completed else { return false }
            
            // Verify: statements before break executed, statements after break did not
            for i in 0..<validBreakPosition {
                if !self.mockContext.keyPresses.contains("before\(i)") {
                    return false
                }
            }
            
            for i in validBreakPosition..<totalStatements {
                if self.mockContext.keyPresses.contains("after\(i)") {
                    return false
                }
            }
            
            // Verify loop only executed once (break prevents second iteration)
            return self.mockContext.keyPresses.count == validBreakPosition
        }
    }
    
    /// Test break prevents condition re-evaluation
    func testBreakPreventsConditionRecheck() {
        mockContext.reset()
        
        // Create while loop with true condition and break
        let whileStmt = WhileStatement(
            condition: .buttonPressed(button: "X"),
            body: [
                .functionCall(FunctionCallStatement(name: "pressKey", arguments: ["a"])),
                .breakStatement(BreakStatement()),
                .functionCall(FunctionCallStatement(name: "pressKey", arguments: ["b"]))
            ]
        )
        
        // Set button as pressed (condition would be true forever without break)
        mockContext.buttonStates["X"] = true
        
        let expectation = XCTestExpectation(description: "Execute while with break")
        Task {
            _ = try? await self.scriptEngine.executeStatement(.whileStatement(whileStmt), context: self.mockContext)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify: only "a" executed, "b" did not, and loop exited
        XCTAssertEqual(mockContext.keyPresses, ["a"])
        
        // Button was only queried once (initial condition check)
        XCTAssertEqual(mockContext.buttonQueries.count, 1)
    }
    
    /// Test break in nested loop only exits inner loop
    func testBreakExitsOnlyInnerLoop() {
        mockContext.reset()
        
        // Create nested loops where inner loop has break
        // Outer loop runs 2 times, inner loop breaks after first statement
        let innerWhile = WhileStatement(
            condition: .boolLiteral(true),
            body: [
                .functionCall(FunctionCallStatement(name: "pressKey", arguments: ["inner"])),
                .breakStatement(BreakStatement())
            ]
        )
        
        // We need to simulate outer loop with a counter
        // For simplicity, we'll test with a single outer iteration
        let outerBody: [AnyStatement] = [
            .functionCall(FunctionCallStatement(name: "pressKey", arguments: ["outer_start"])),
            .whileStatement(innerWhile),
            .functionCall(FunctionCallStatement(name: "pressKey", arguments: ["outer_end"]))
        ]
        
        // Execute outer body directly (simulating one iteration of outer loop)
        let expectation = XCTestExpectation(description: "Execute nested loops")
        Task {
            _ = try? await self.scriptEngine.executeStatements(outerBody, context: self.mockContext)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify: outer_start, inner, outer_end all executed
        // Break only exited inner loop, outer continued
        XCTAssertEqual(mockContext.keyPresses, ["outer_start", "inner", "outer_end"])
    }
    
    /// Test break returns normal control after exiting loop
    func testBreakReturnsNormalControlAfterLoop() {
        let whileStmt = WhileStatement(
            condition: .boolLiteral(true),
            body: [
                .breakStatement(BreakStatement())
            ]
        )
        
        let expectation = XCTestExpectation(description: "Execute while with break")
        var executionControl: ExecutionControl = .breakLoop
        
        Task {
            executionControl = try await self.scriptEngine.executeStatement(.whileStatement(whileStmt), context: self.mockContext)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // While loop should return normal (break is consumed by the loop)
        XCTAssertEqual(executionControl, .normal)
    }
    
    /// Test break inside if statement within loop
    func testBreakInsideIfWithinLoop() {
        mockContext.reset()
        
        // while (true) { pressKey("a"); if (true) { break } pressKey("b") }
        let ifWithBreak = IfStatement(
            condition: .boolLiteral(true),
            thenBlock: [.breakStatement(BreakStatement())],
            elseBlock: nil
        )
        
        let whileStmt = WhileStatement(
            condition: .boolLiteral(true),
            body: [
                .functionCall(FunctionCallStatement(name: "pressKey", arguments: ["a"])),
                .ifStatement(ifWithBreak),
                .functionCall(FunctionCallStatement(name: "pressKey", arguments: ["b"]))
            ]
        )
        
        let expectation = XCTestExpectation(description: "Execute while with if containing break")
        Task {
            _ = try? await self.scriptEngine.executeStatement(.whileStatement(whileStmt), context: self.mockContext)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify: "a" executed, break triggered, "b" did not execute
        XCTAssertEqual(mockContext.keyPresses, ["a"])
    }
    
    /// Property test: break at any position stops execution
    func testBreakAtAnyPositionStopsExecution() {
        property("Break at any position stops loop") <- forAll(
            Gen<Int>.fromElements(in: 0...5)
        ) { (breakPosition: Int) in
            self.mockContext.reset()
            
            var body: [AnyStatement] = []
            
            // Add statements with break at specified position
            for i in 0...5 {
                if i == breakPosition {
                    body.append(.breakStatement(BreakStatement()))
                }
                body.append(.functionCall(FunctionCallStatement(name: "pressKey", arguments: ["\(i)"])))
            }
            
            let whileStmt = WhileStatement(
                condition: .boolLiteral(true),
                body: body
            )
            
            let expectation = XCTestExpectation(description: "Execute while with break")
            Task {
                _ = try? await self.scriptEngine.executeStatement(.whileStatement(whileStmt), context: self.mockContext)
                expectation.fulfill()
            }
            
            let result = XCTWaiter.wait(for: [expectation], timeout: 2.0)
            guard result == .completed else { return false }
            
            // Verify exactly breakPosition statements executed
            return self.mockContext.keyPresses.count == breakPosition
        }
    }
}
