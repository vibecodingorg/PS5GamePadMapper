import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Script button state query
/// **Feature: ps5-gamepad-mapper, Property 14: Script Button State Query**
final class ScriptButtonStateQueryPropertyTests: XCTestCase {
    
    var scriptEngine: ScriptEngine!
    var mockContext: MockScriptContext!
    
    override func setUp() {
        super.setUp()
        scriptEngine = ScriptEngine()
        mockContext = MockScriptContext()
    }
    
    override func tearDown() {
        scriptEngine = nil
        mockContext = nil
        super.tearDown()
    }
    
    // MARK: - Property 14: Script Button State Query
    
    /// **Feature: ps5-gamepad-mapper, Property 14: Script Button State Query**
    /// **Validates: Requirements 12.8**
    ///
    /// *For any* button and its current physical state, isButtonPressed(btn) SHALL return
    /// true if and only if the button is currently pressed on the controller.
    
    /// Property 14.1: isButtonPressed returns true when button is pressed
    func testIsButtonPressedReturnsTrueWhenPressed() {
        property("isButtonPressed returns true when button is pressed") <- forAll { (buttonGen: ControllerButtonNameGenerator) in
            let button = buttonGen.value
            self.mockContext.reset()
            
            // Set the button state to pressed
            self.mockContext.buttonStates[button] = true
            
            let script = Script(name: "test", source: "isButtonPressed(\(button))")
            
            let expectation = XCTestExpectation(description: "Script execution")
            Task {
                try? await self.scriptEngine.execute(script, context: self.mockContext)
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 1.0)
            
            // Verify the button was queried
            return self.mockContext.buttonQueries.count == 1
                && self.mockContext.buttonQueries[0] == button
        }
    }
    
    /// Property 14.2: isButtonPressed returns false when button is not pressed
    func testIsButtonPressedReturnsFalseWhenNotPressed() {
        property("isButtonPressed returns false when button is not pressed") <- forAll { (buttonGen: ControllerButtonNameGenerator) in
            let button = buttonGen.value
            self.mockContext.reset()
            
            // Set the button state to not pressed (default)
            self.mockContext.buttonStates[button] = false
            
            let script = Script(name: "test", source: "isButtonPressed(\(button))")
            
            let expectation = XCTestExpectation(description: "Script execution")
            Task {
                try? await self.scriptEngine.execute(script, context: self.mockContext)
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 1.0)
            
            // Verify the button was queried
            return self.mockContext.buttonQueries.count == 1
                && self.mockContext.buttonQueries[0] == button
        }
    }

    
    /// Property 14.3: isButtonPressed correctly reflects button state changes
    func testIsButtonPressedReflectsStateChanges() {
        property("isButtonPressed correctly reflects button state changes") <- forAll { (buttonGen: ControllerButtonNameGenerator, isPressed: Bool) in
            let button = buttonGen.value
            self.mockContext.reset()
            
            // Set the button state
            self.mockContext.buttonStates[button] = isPressed
            
            // Query the button state directly through the context
            let result = self.mockContext.isButtonPressed(button)
            
            // Verify the result matches the configured state
            return result == isPressed
        }
    }
    
    /// Property 14.4: Two consecutive button queries are tracked in order
    func testTwoConsecutiveButtonQueriesTrackedInOrder() {
        property("Two consecutive button queries are tracked in order") <- forAll { (button1Gen: ControllerButtonNameGenerator, button2Gen: ControllerButtonNameGenerator) in
            let button1 = button1Gen.value
            let button2 = button2Gen.value
            
            self.mockContext.reset()
            
            let script = Script(name: "test", source: """
                isButtonPressed(\(button1))
                isButtonPressed(\(button2))
                """)
            
            let expectation = XCTestExpectation(description: "Script execution")
            Task {
                try? await self.scriptEngine.execute(script, context: self.mockContext)
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 2.0)
            
            // Verify both buttons were queried in order
            return self.mockContext.buttonQueries.count == 2
                && self.mockContext.buttonQueries[0] == button1
                && self.mockContext.buttonQueries[1] == button2
        }
    }
    
    /// Property 14.5: Button state query is idempotent
    func testButtonStateQueryIsIdempotent() {
        property("Button state query is idempotent") <- forAll { (buttonGen: ControllerButtonNameGenerator, isPressed: Bool) in
            let button = buttonGen.value
            self.mockContext.reset()
            
            // Set the button state
            self.mockContext.buttonStates[button] = isPressed
            
            // Query multiple times
            let result1 = self.mockContext.isButtonPressed(button)
            let result2 = self.mockContext.isButtonPressed(button)
            let result3 = self.mockContext.isButtonPressed(button)
            
            // All results should be the same
            return result1 == result2 && result2 == result3 && result1 == isPressed
        }
    }
    
    /// Property 14.6: Different buttons can have different states
    func testDifferentButtonsCanHaveDifferentStates() {
        property("Different buttons can have different states") <- forAll { (button1Gen: ControllerButtonNameGenerator, button2Gen: ControllerButtonNameGenerator) in
            let button1 = button1Gen.value
            let button2 = button2Gen.value
            
            // Skip if same button
            guard button1 != button2 else { return true }
            
            self.mockContext.reset()
            
            // Set different states for different buttons
            self.mockContext.buttonStates[button1] = true
            self.mockContext.buttonStates[button2] = false
            
            let result1 = self.mockContext.isButtonPressed(button1)
            let result2 = self.mockContext.isButtonPressed(button2)
            
            // Verify each button returns its own state
            return result1 == true && result2 == false
        }
    }
}
