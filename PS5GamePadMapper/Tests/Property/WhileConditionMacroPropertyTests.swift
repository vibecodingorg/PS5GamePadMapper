import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for WhileCondition macro execution
/// **Feature: macro-script-enhancements, Property 11: WhileCondition Macro Execution**
final class WhileConditionMacroPropertyTests: XCTestCase {
    
    // MARK: - Mock Event Emitter
    
    class MockEventEmitter: EventEmitterProtocol {
        var keyDownEvents: [(keyCode: UInt16, modifiers: KeyModifiers)] = []
        var keyUpEvents: [(keyCode: UInt16, modifiers: KeyModifiers)] = []
        var mouseDownEvents: [MouseButton] = []
        var mouseUpEvents: [MouseButton] = []
        var mouseMoveEvents: [(dx: CGFloat, dy: CGFloat)] = []
        var mouseScrollEvents: [(dx: CGFloat, dy: CGFloat)] = []
        
        func emitKeyDown(_ keyCode: UInt16, modifiers: KeyModifiers) {
            keyDownEvents.append((keyCode, modifiers))
        }
        
        func emitKeyUp(_ keyCode: UInt16, modifiers: KeyModifiers) {
            keyUpEvents.append((keyCode, modifiers))
        }
        
        func emitMouseDown(_ button: MouseButton) {
            mouseDownEvents.append(button)
        }
        
        func emitMouseUp(_ button: MouseButton) {
            mouseUpEvents.append(button)
        }
        
        func emitMouseMove(dx: CGFloat, dy: CGFloat) {
            mouseMoveEvents.append((dx, dy))
        }
        
        func emitMouseScroll(dx: CGFloat, dy: CGFloat) {
            mouseScrollEvents.append((dx, dy))
        }
        
        func reset() {
            keyDownEvents.removeAll()
            keyUpEvents.removeAll()
            mouseDownEvents.removeAll()
            mouseUpEvents.removeAll()
            mouseMoveEvents.removeAll()
            mouseScrollEvents.removeAll()
        }
    }
    
    // MARK: - Property 11: WhileCondition Macro Execution
    
    /// **Feature: macro-script-enhancements, Property 11: WhileCondition Macro Execution**
    /// **Validates: Requirements 4.2, 4.3, 4.4**
    ///
    /// *For any* whileCondition macro where the condition becomes false after N iterations,
    /// the macro steps SHALL execute exactly N times.
    func testWhileConditionMacroExecutesCorrectIterations() {
        // Test with various iteration counts
        property("WhileCondition macro executes correct number of iterations") <- forAll(
            Gen.fromElements(in: 0...10)
        ) { (targetIterations: Int) in
            let emitter = MockEventEmitter()
            let scheduler = MacroScheduler(eventEmitter: emitter)
            
            // Track iteration count
            var currentIteration = 0
            
            // Set up button state provider that returns true for targetIterations times
            scheduler.buttonStateProvider = { button in
                let shouldContinue = currentIteration < targetIterations
                if shouldContinue {
                    currentIteration += 1
                }
                return shouldContinue
            }
            
            // Create a simple macro with one step
            let step = MacroStep.keyDown(keyCode: 42)
            let macro = Macro(
                name: "TestWhileCondition",
                steps: [step],
                type: .whileCondition(condition: "isButtonPressed(\"cross\")")
            )
            
            // Execute synchronously
            scheduler.executeSynchronously(macro)
            
            // Verify the step was executed exactly targetIterations times
            return emitter.keyDownEvents.count == targetIterations
        }
    }
    
    /// Test that whileCondition macro stops when condition becomes false
    /// **Validates: Requirements 4.4**
    func testWhileConditionMacroStopsWhenConditionFalse() {
        property("WhileCondition macro stops when condition is false") <- forAll(
            Gen.fromElements(in: 1...5)
        ) { (iterations: Int) in
            let emitter = MockEventEmitter()
            let scheduler = MacroScheduler(eventEmitter: emitter)
            
            var callCount = 0
            scheduler.buttonStateProvider = { _ in
                callCount += 1
                return callCount <= iterations
            }
            
            let macro = Macro(
                name: "TestStop",
                steps: [.keyDown(keyCode: 1)],
                type: .whileCondition(condition: "isButtonPressed(\"cross\")")
            )
            
            scheduler.executeSynchronously(macro)
            
            // Should have executed exactly 'iterations' times
            return emitter.keyDownEvents.count == iterations
        }
    }
    
    /// Test that whileCondition macro with false condition executes zero times
    /// **Validates: Requirements 4.2, 4.3**
    func testWhileConditionMacroWithFalseConditionExecutesZeroTimes() {
        let emitter = MockEventEmitter()
        let scheduler = MacroScheduler(eventEmitter: emitter)
        
        // Condition always false
        scheduler.buttonStateProvider = { _ in false }
        
        let macro = Macro(
            name: "TestZeroIterations",
            steps: [.keyDown(keyCode: 1), .keyUp(keyCode: 1)],
            type: .whileCondition(condition: "isButtonPressed(\"cross\")")
        )
        
        scheduler.executeSynchronously(macro)
        
        // Should not have executed any steps
        XCTAssertEqual(emitter.keyDownEvents.count, 0)
        XCTAssertEqual(emitter.keyUpEvents.count, 0)
    }
    
    /// Test that whileCondition macro evaluates condition before each iteration
    /// **Validates: Requirements 4.2**
    func testWhileConditionMacroEvaluatesConditionBeforeEachIteration() {
        property("Condition is evaluated before each iteration") <- forAll(
            Gen.fromElements(in: 1...5)
        ) { (maxIterations: Int) in
            let emitter = MockEventEmitter()
            let scheduler = MacroScheduler(eventEmitter: emitter)
            
            var evaluationCount = 0
            scheduler.buttonStateProvider = { _ in
                evaluationCount += 1
                return evaluationCount <= maxIterations
            }
            
            let macro = Macro(
                name: "TestEvaluation",
                steps: [.keyDown(keyCode: 1)],
                type: .whileCondition(condition: "isButtonPressed(\"cross\")")
            )
            
            scheduler.executeSynchronously(macro)
            
            // Condition should be evaluated maxIterations + 1 times
            // (once for each iteration + once when it becomes false)
            return evaluationCount == maxIterations + 1
        }
    }
}


// MARK: - Property 12: WhileCondition Button State Integration

extension WhileConditionMacroPropertyTests {
    
    /// **Feature: macro-script-enhancements, Property 12: WhileCondition Button State Integration**
    /// **Validates: Requirements 4.5**
    ///
    /// *For any* whileCondition macro with a button state condition, the condition evaluation
    /// SHALL reflect the current controller button state at each iteration.
    func testWhileConditionButtonStateIntegration() {
        // Test with different button names
        let buttonNames = ["cross", "circle", "square", "triangle", "L1", "R1"]
        
        for buttonName in buttonNames {
            let emitter = MockEventEmitter()
            let scheduler = MacroScheduler(eventEmitter: emitter)
            
            var buttonPressed = true
            var queryCount = 0
            let maxQueries = 3
            
            // Button state provider that tracks queries and changes state
            scheduler.buttonStateProvider = { queriedButton in
                // Verify the correct button is being queried
                guard queriedButton == buttonName else { return false }
                
                queryCount += 1
                if queryCount > maxQueries {
                    buttonPressed = false
                }
                return buttonPressed
            }
            
            let macro = Macro(
                name: "TestButtonState",
                steps: [.keyDown(keyCode: 1)],
                type: .whileCondition(condition: "isButtonPressed(\"\(buttonName)\")")
            )
            
            scheduler.executeSynchronously(macro)
            
            // Should have executed maxQueries times (while button was pressed)
            XCTAssertEqual(emitter.keyDownEvents.count, maxQueries,
                          "Button \(buttonName) should have triggered \(maxQueries) iterations")
        }
    }
    
    /// Test that button state is queried at each iteration
    /// **Validates: Requirements 4.5**
    func testButtonStateQueriedAtEachIteration() {
        property("Button state is queried before each iteration") <- forAll(
            Gen.fromElements(in: 1...5)
        ) { (iterations: Int) in
            let emitter = MockEventEmitter()
            let scheduler = MacroScheduler(eventEmitter: emitter)
            
            var queryCount = 0
            scheduler.buttonStateProvider = { _ in
                queryCount += 1
                return queryCount <= iterations
            }
            
            let macro = Macro(
                name: "TestQuery",
                steps: [.keyDown(keyCode: 1)],
                type: .whileCondition(condition: "isButtonPressed(\"cross\")")
            )
            
            scheduler.executeSynchronously(macro)
            
            // Query count should be iterations + 1 (one extra for the false check)
            return queryCount == iterations + 1
        }
    }
    
    /// Test that different buttons can be used in conditions
    /// **Validates: Requirements 4.5**
    func testDifferentButtonsInConditions() {
        property("Different buttons can be used in whileCondition") <- forAll(
            Gen.fromElements(of: ["cross", "circle", "square", "triangle", "L1", "R1", "L2", "R2"])
        ) { (buttonName: String) in
            let emitter = MockEventEmitter()
            let scheduler = MacroScheduler(eventEmitter: emitter)
            
            var queriedButton: String? = nil
            scheduler.buttonStateProvider = { button in
                queriedButton = button
                return false // Stop immediately
            }
            
            let macro = Macro(
                name: "TestButton",
                steps: [.keyDown(keyCode: 1)],
                type: .whileCondition(condition: "isButtonPressed(\"\(buttonName)\")")
            )
            
            scheduler.executeSynchronously(macro)
            
            // Verify the correct button was queried
            return queriedButton == buttonName
        }
    }
    
    /// Test that button state changes are reflected immediately
    /// **Validates: Requirements 4.5**
    func testButtonStateChangesReflectedImmediately() {
        let emitter = MockEventEmitter()
        let scheduler = MacroScheduler(eventEmitter: emitter)
        
        var iterationCount = 0
        let stopAfter = 2
        
        // Button becomes unpressed after stopAfter iterations
        scheduler.buttonStateProvider = { _ in
            iterationCount += 1
            return iterationCount <= stopAfter
        }
        
        let macro = Macro(
            name: "TestImmediate",
            steps: [.keyDown(keyCode: 1), .keyUp(keyCode: 1)],
            type: .whileCondition(condition: "isButtonPressed(\"cross\")")
        )
        
        scheduler.executeSynchronously(macro)
        
        // Should have executed exactly stopAfter times
        XCTAssertEqual(emitter.keyDownEvents.count, stopAfter)
        XCTAssertEqual(emitter.keyUpEvents.count, stopAfter)
    }
}
