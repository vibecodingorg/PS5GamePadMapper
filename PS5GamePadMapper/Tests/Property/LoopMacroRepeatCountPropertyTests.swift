import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Wrapper struct for loop macro test data
struct LoopMacroTestData: Arbitrary {
    let macro: Macro
    let expectedCount: Int
    
    static var arbitrary: Gen<LoopMacroTestData> {
        Gen.compose { c in
            // Generate 1-5 steps for meaningful tests
            let stepCount: Int = c.generate(using: Gen.fromElements(in: 1...5))
            var steps: [MacroStep] = []
            
            for _ in 0..<stepCount {
                // Generate steps without delays for faster testing
                let step: MacroStep = c.generate(using: Gen.one(of: [
                    Gen.fromElements(in: 0...50).map { MacroStep.keyDown(keyCode: UInt16($0)) },
                    Gen.fromElements(in: 0...50).map { MacroStep.keyUp(keyCode: UInt16($0)) },
                    MouseButton.arbitrary.map { MacroStep.mouseClick(button: $0) },
                    Gen.zip(Gen.fromElements(in: -100...100), Gen.fromElements(in: -100...100))
                        .map { MacroStep.mouseMove(dx: $0.0, dy: $0.1) }
                ]))
                steps.append(step)
            }
            
            // Generate repeat count between 1 and 10
            let maxCount: Int = c.generate(using: Gen.fromElements(in: 1...10))
            
            // Use minimal interval for fast testing
            let interval = 1
            
            let macro = Macro(
                id: UUID(),
                name: "LoopMacro",
                steps: steps,
                type: .loop(interval: interval, maxCount: maxCount)
            )
            
            return LoopMacroTestData(macro: macro, expectedCount: maxCount)
        }
    }
}

/// Property-based tests for Loop Macro repeat count
/// **Feature: ps5-gamepad-mapper, Property 9: Loop Macro Repeat Count**
final class LoopMacroRepeatCountPropertyTests: XCTestCase {
    
    // MARK: - Test Fixtures
    
    private var mockEmitter: MockEventEmitter!
    private var scheduler: MacroScheduler!
    
    override func setUp() {
        super.setUp()
        mockEmitter = MockEventEmitter()
        scheduler = MacroScheduler(eventEmitter: mockEmitter)
        scheduler.recordSteps = true
    }
    
    override func tearDown() {
        scheduler.resetAll()
        mockEmitter = nil
        scheduler = nil
        super.tearDown()
    }
    
    // MARK: - Property 9: Loop Macro Repeat Count
    
    /// **Feature: ps5-gamepad-mapper, Property 9: Loop Macro Repeat Count**
    /// **Validates: Requirements 9.4**
    ///
    /// *For any* loop macro with a maximum repeat count N (where N > 0),
    /// the macro SHALL execute exactly N iterations before stopping.
    func testLoopMacroRepeatCount() {
        property("Loop macro executes exactly N iterations when maxCount is N") <- forAll { (testData: LoopMacroTestData) in
            let macro = testData.macro
            let expectedCount = testData.expectedCount
            // Reset state
            self.scheduler.resetAll()
            self.scheduler.recordSteps = true
            self.mockEmitter.reset()
            
            // Execute the macro synchronously
            self.scheduler.executeSynchronously(macro)
            
            // Calculate expected total steps
            let stepsPerIteration = macro.steps.count
            let expectedTotalSteps = stepsPerIteration * expectedCount
            
            // Verify the total number of executed steps
            let actualTotalSteps = self.scheduler.executedSteps.count
            
            return actualTotalSteps == expectedTotalSteps
        }
    }

    
    /// Additional property: Each iteration executes all steps in order
    func testLoopMacroIterationsExecuteAllSteps() {
        property("Each loop iteration executes all steps in order") <- forAll { (testData: LoopMacroTestData) in
            let macro = testData.macro
            let expectedCount = testData.expectedCount
            
            guard !macro.steps.isEmpty else { return true }
            
            self.scheduler.resetAll()
            self.scheduler.recordSteps = true
            self.scheduler.executeSynchronously(macro)
            
            let executedSteps = self.scheduler.executedSteps
            let stepsPerIteration = macro.steps.count
            
            // Verify each iteration
            for iteration in 0..<expectedCount {
                for stepIndex in 0..<stepsPerIteration {
                    let globalIndex = iteration * stepsPerIteration + stepIndex
                    guard globalIndex < executedSteps.count else { return false }
                    
                    let (recordedIndex, recordedStep) = executedSteps[globalIndex]
                    
                    // Index within iteration should match
                    guard recordedIndex == stepIndex else { return false }
                    // Step should match original
                    guard recordedStep == macro.steps[stepIndex] else { return false }
                }
            }
            
            return true
        }
    }
}
