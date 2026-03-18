import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Macro step order preservation
/// **Feature: ps5-gamepad-mapper, Property 8: Macro Step Order Preservation**
final class MacroStepOrderPropertyTests: XCTestCase {
    
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
    
    // MARK: - Property 8: Macro Step Order Preservation
    
    /// **Feature: ps5-gamepad-mapper, Property 8: Macro Step Order Preservation**
    /// **Validates: Requirements 8.1**
    ///
    /// *For any* sequence macro execution, the steps SHALL be executed in the exact order
    /// they are defined, with no reordering or skipping.
    func testMacroStepOrderPreservation() {
        property("Macro steps are executed in exact definition order") <- forAll(self.sequenceMacroGenerator) { (macro: Macro) in
            // Reset state
            self.scheduler.resetAll()
            self.scheduler.recordSteps = true
            
            // Execute the macro synchronously
            self.scheduler.executeSynchronously(macro)
            
            // Get the executed steps
            let executedSteps = self.scheduler.executedSteps
            
            // Verify count matches (no skipping)
            guard executedSteps.count == macro.steps.count else {
                return false
            }
            
            // Verify order matches (no reordering)
            for (index, (executedIndex, executedStep)) in executedSteps.enumerated() {
                // Index should match position
                guard executedIndex == index else {
                    return false
                }
                // Step should match original
                guard executedStep == macro.steps[index] else {
                    return false
                }
            }
            
            return true
        }
    }

    
    /// Additional property: Step indices are sequential
    func testMacroStepIndicesAreSequential() {
        property("Executed step indices are sequential starting from 0") <- forAll(self.sequenceMacroGenerator) { (macro: Macro) in
            guard !macro.steps.isEmpty else { return true }
            
            self.scheduler.resetAll()
            self.scheduler.recordSteps = true
            self.scheduler.executeSynchronously(macro)
            
            let indices = self.scheduler.executedSteps.map { $0.index }
            let expectedIndices = Array(0..<macro.steps.count)
            
            return indices == expectedIndices
        }
    }
    
    // MARK: - Generators
    
    /// Generator for sequence macros only (no loops or toggles)
    private var sequenceMacroGenerator: Gen<Macro> {
        Gen.compose { c in
            // Generate 1-10 steps for meaningful tests
            let stepCount: Int = c.generate(using: Gen.fromElements(in: 1...10))
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
            
            return Macro(
                id: UUID(),
                name: "TestMacro",
                steps: steps,
                type: .sequence
            )
        }
    }
}

// MARK: - Mock Event Emitter

/// Mock event emitter for testing that records all emitted events
final class MockEventEmitter: EventEmitterProtocol {
    var emittedEvents: [MockEvent] = []
    
    enum MockEvent: Equatable {
        case keyDown(keyCode: UInt16, modifiers: KeyModifiers)
        case keyUp(keyCode: UInt16, modifiers: KeyModifiers)
        case mouseDown(button: MouseButton)
        case mouseUp(button: MouseButton)
        case mouseMove(dx: CGFloat, dy: CGFloat)
        case mouseScroll(dx: CGFloat, dy: CGFloat)
    }
    
    func emitKeyDown(_ keyCode: UInt16, modifiers: KeyModifiers) {
        emittedEvents.append(.keyDown(keyCode: keyCode, modifiers: modifiers))
    }
    
    func emitKeyUp(_ keyCode: UInt16, modifiers: KeyModifiers) {
        emittedEvents.append(.keyUp(keyCode: keyCode, modifiers: modifiers))
    }
    
    func emitMouseDown(_ button: MouseButton) {
        emittedEvents.append(.mouseDown(button: button))
    }
    
    func emitMouseUp(_ button: MouseButton) {
        emittedEvents.append(.mouseUp(button: button))
    }
    
    func emitMouseMove(dx: CGFloat, dy: CGFloat) {
        emittedEvents.append(.mouseMove(dx: dx, dy: dy))
    }
    
    func emitMouseScroll(dx: CGFloat, dy: CGFloat) {
        emittedEvents.append(.mouseScroll(dx: dx, dy: dy))
    }
    
    func reset() {
        emittedEvents.removeAll()
    }
}
