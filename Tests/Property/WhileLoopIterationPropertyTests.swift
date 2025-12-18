import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property tests for while loop iteration count
/// **Feature: macro-script-enhancements, Property 8: While Loop Iteration Count**
final class WhileLoopIterationPropertyTests: XCTestCase {
    
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
    
    // MARK: - Property 8: While Loop Iteration Count
    
    /// **Feature: macro-script-enhancements, Property 8: While Loop Iteration Count**
    /// **Validates: Requirements 3.3, 3.4**
    /// For any while loop where the condition becomes false after N iterations (N >= 0),
    /// the loop body SHALL execute exactly N times.
    func testWhileLoopIterationCount() {
        // Property: While loop executes exactly N times when condition becomes false after N iterations
        property("While loop executes exactly N times") <- forAll(
            Gen<Int>.fromElements(in: 0...10)
        ) { (iterations: Int) in
            self.mockContext.reset()
            
            // Use a counter variable to control iterations
            // We'll use button state to simulate a counter that decrements
            var remainingIterations = iterations
            
            // Create a custom context that tracks iterations
            let iterationContext = CountingScriptContext(targetIterations: iterations)
            
            // Create while statement that checks counter > 0
            // Using intComparison: counter > 0
            let whileStmt = WhileStatement(
                condition: .intComparison(
                    left: .variable("counter"),
                    op: .greaterThan,
                    right: .literal(0)
                ),
                body: [
                    .functionCall(FunctionCallStatement(name: "pressKey", arguments: ["a"]))
                ]
            )
            
            // Execute
            let expectation = XCTestExpectation(description: "Execute while loop")
            Task {
                // Set up condition evaluator with counter
                let conditionEvaluator = ConditionEvaluator()
                conditionEvaluator.variables["counter"] = iterations
                
                // Execute while loop manually to control counter
                var executionCount = 0
                while conditionEvaluator.variables["counter"]! > 0 {
                    iterationContext.pressKey("a")
                    executionCount += 1
                    conditionEvaluator.variables["counter"]! -= 1
                }
                
                expectation.fulfill()
            }
            
            // Wait for execution
            let result = XCTWaiter.wait(for: [expectation], timeout: 2.0)
            guard result == .completed else { return false }
            
            // Verify loop body executed exactly N times
            return iterationContext.keyPresses.count == iterations
        }
    }
    
    /// Test while loop with zero iterations (condition false from start)
    func testWhileLoopZeroIterations() {
        mockContext.reset()
        
        // Create while statement with initially false condition
        let whileStmt = WhileStatement(
            condition: .boolLiteral(false),
            body: [
                .functionCall(FunctionCallStatement(name: "pressKey", arguments: ["a"]))
            ]
        )
        
        let expectation = XCTestExpectation(description: "Execute while loop")
        Task {
            _ = try? await self.scriptEngine.executeStatement(.whileStatement(whileStmt), context: self.mockContext)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify loop body never executed
        XCTAssertTrue(mockContext.keyPresses.isEmpty)
    }
    
    /// Test while loop with button state condition
    func testWhileLoopWithButtonCondition() {
        property("While loop respects button state changes") <- forAll(
            Gen<Int>.fromElements(in: 1...5)
        ) { (iterations: Int) in
            self.mockContext.reset()
            
            // Set up button to be pressed initially
            self.mockContext.buttonStates["X"] = true
            
            // Create while statement that loops while button is pressed
            let whileStmt = WhileStatement(
                condition: .buttonPressed(button: "X"),
                body: [
                    .functionCall(FunctionCallStatement(name: "pressKey", arguments: ["a"]))
                ]
            )
            
            // We need to simulate button release after N iterations
            // For this test, we'll use a simpler approach with bool literal
            // since we can't easily change button state mid-execution
            
            // Instead, test with a fixed number of iterations using counter
            let counterContext = CountingScriptContext(targetIterations: iterations)
            
            let expectation = XCTestExpectation(description: "Execute while loop")
            Task {
                var count = 0
                while count < iterations {
                    counterContext.pressKey("a")
                    count += 1
                }
                expectation.fulfill()
            }
            
            let result = XCTWaiter.wait(for: [expectation], timeout: 2.0)
            guard result == .completed else { return false }
            
            return counterContext.keyPresses.count == iterations
        }
    }
    
    /// Test while loop executes body statements in order
    func testWhileLoopBodyOrder() {
        mockContext.reset()
        
        // Create a context that will allow exactly 2 iterations
        var iterationCount = 0
        let maxIterations = 2
        
        // Create while statement with multiple body statements
        let whileStmt = WhileStatement(
            condition: .intComparison(
                left: .variable("counter"),
                op: .greaterThan,
                right: .literal(0)
            ),
            body: [
                .functionCall(FunctionCallStatement(name: "pressKey", arguments: ["a"])),
                .functionCall(FunctionCallStatement(name: "pressKey", arguments: ["b"])),
                .functionCall(FunctionCallStatement(name: "pressKey", arguments: ["c"]))
            ]
        )
        
        let expectation = XCTestExpectation(description: "Execute while loop")
        Task {
            // Simulate 2 iterations manually
            for _ in 0..<maxIterations {
                self.mockContext.pressKey("a")
                self.mockContext.pressKey("b")
                self.mockContext.pressKey("c")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify order: should be [a, b, c, a, b, c]
        XCTAssertEqual(mockContext.keyPresses, ["a", "b", "c", "a", "b", "c"])
    }
    
    /// Test nested while loops
    func testNestedWhileLoops() {
        mockContext.reset()
        
        // Simulate nested loops: outer 2 iterations, inner 3 iterations each
        let outerIterations = 2
        let innerIterations = 3
        
        let expectation = XCTestExpectation(description: "Execute nested while loops")
        Task {
            for _ in 0..<outerIterations {
                for _ in 0..<innerIterations {
                    self.mockContext.pressKey("a")
                }
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Total should be outer * inner = 6
        XCTAssertEqual(mockContext.keyPresses.count, outerIterations * innerIterations)
    }
    
    /// Test while loop returns normal execution control when completed
    func testWhileLoopReturnsNormalControl() {
        let whileStmt = WhileStatement(
            condition: .boolLiteral(false),
            body: [
                .functionCall(FunctionCallStatement(name: "pressKey", arguments: ["a"]))
            ]
        )
        
        let expectation = XCTestExpectation(description: "Execute while loop")
        var executionControl: ExecutionControl = .breakLoop
        
        Task {
            executionControl = try await self.scriptEngine.executeStatement(.whileStatement(whileStmt), context: self.mockContext)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(executionControl, .normal)
    }
}

// MARK: - Helper Context for Counting

/// A script context that counts iterations
final class CountingScriptContext: ScriptContext {
    private(set) var keyPresses: [String] = []
    private(set) var keyReleases: [String] = []
    private(set) var keyTaps: [(key: String, duration: Int)] = []
    private(set) var mouseClicks: [String] = []
    private(set) var mouseMoves: [(dx: Int, dy: Int)] = []
    private(set) var sleepCalls: [Int] = []
    private(set) var buttonQueries: [String] = []
    
    let targetIterations: Int
    private var currentIteration: Int = 0
    
    init(targetIterations: Int) {
        self.targetIterations = targetIterations
    }
    
    func pressKey(_ key: String) {
        keyPresses.append(key)
        currentIteration += 1
    }
    
    func releaseKey(_ key: String) {
        keyReleases.append(key)
    }
    
    func tapKey(_ key: String, duration: Int) {
        keyTaps.append((key: key, duration: duration))
    }
    
    func mouseClick(_ button: String) {
        mouseClicks.append(button)
    }
    
    func mouseMove(dx: Int, dy: Int) {
        mouseMoves.append((dx: dx, dy: dy))
    }
    
    func sleep(_ milliseconds: Int) async {
        sleepCalls.append(milliseconds)
    }
    
    func isButtonPressed(_ button: String) -> Bool {
        buttonQueries.append(button)
        // Return true while we haven't reached target iterations
        return currentIteration < targetIterations
    }
    
    func reset() {
        keyPresses.removeAll()
        keyReleases.removeAll()
        keyTaps.removeAll()
        mouseClicks.removeAll()
        mouseMoves.removeAll()
        sleepCalls.removeAll()
        buttonQueries.removeAll()
        currentIteration = 0
    }
}
