import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Script API mouse events
/// **Feature: ps5-gamepad-mapper, Property 13: Script API Mouse Events**
final class ScriptAPIMouseEventsPropertyTests: XCTestCase {
    
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
    
    // MARK: - Property 13: Script API Mouse Events
    
    /// **Feature: ps5-gamepad-mapper, Property 13: Script API Mouse Events**
    /// **Validates: Requirements 12.5, 12.6**
    ///
    /// *For any* mouse action specified in script API calls:
    /// - mouseClick(button) SHALL emit a complete click (down + up) for the specified button
    /// - mouseMove(dx, dy) SHALL emit a relative movement event with the exact delta values
    
    /// Property 13.1: mouseClick emits a complete click for the specified button
    func testMouseClickEmitsCompleteClick() {
        property("mouseClick emits a complete click for the specified button") <- forAll { (buttonGen: MouseButtonNameGenerator) in
            let button = buttonGen.value
            self.mockContext.reset()
            
            let script = Script(name: "test", source: "mouseClick(\(button))")
            
            let expectation = XCTestExpectation(description: "Script execution")
            Task {
                try? await self.scriptEngine.execute(script, context: self.mockContext)
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 1.0)
            
            // Verify exactly one mouse click was emitted for the specified button
            return self.mockContext.mouseClicks.count == 1
                && self.mockContext.mouseClicks[0].lowercased() == button.lowercased()
        }
    }
    
    /// Property 13.2: mouseMove emits movement with exact delta values
    func testMouseMoveEmitsExactDeltaValues() {
        property("mouseMove emits movement with exact delta values") <- forAll { (deltaGen: MouseDeltaGenerator) in
            let dx = deltaGen.dx
            let dy = deltaGen.dy
            self.mockContext.reset()
            
            let script = Script(name: "test", source: "mouseMove(\(dx), \(dy))")
            
            let expectation = XCTestExpectation(description: "Script execution")
            Task {
                try? await self.scriptEngine.execute(script, context: self.mockContext)
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 1.0)
            
            // Verify exactly one mouse move was emitted with exact delta values
            return self.mockContext.mouseMoves.count == 1
                && self.mockContext.mouseMoves[0].dx == dx
                && self.mockContext.mouseMoves[0].dy == dy
        }
    }

    
    /// Property 13.3: Two consecutive mouseClick commands emit clicks in order
    func testTwoConsecutiveMouseClicksEmitInOrder() {
        property("Two consecutive mouseClick commands emit clicks in order") <- forAll { (button1Gen: MouseButtonNameGenerator, button2Gen: MouseButtonNameGenerator) in
            let button1 = button1Gen.value
            let button2 = button2Gen.value
            
            self.mockContext.reset()
            
            let script = Script(name: "test", source: """
                mouseClick(\(button1))
                mouseClick(\(button2))
                """)
            
            let expectation = XCTestExpectation(description: "Script execution")
            Task {
                try? await self.scriptEngine.execute(script, context: self.mockContext)
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 2.0)
            
            // Verify both clicks were emitted in order
            return self.mockContext.mouseClicks.count == 2
                && self.mockContext.mouseClicks[0].lowercased() == button1.lowercased()
                && self.mockContext.mouseClicks[1].lowercased() == button2.lowercased()
        }
    }
    
    /// Property 13.4: Two consecutive mouseMove commands emit movements in order
    func testTwoConsecutiveMouseMovesEmitInOrder() {
        property("Two consecutive mouseMove commands emit movements in order") <- forAll { (delta1Gen: MouseDeltaGenerator, delta2Gen: MouseDeltaGenerator) in
            let dx1 = delta1Gen.dx
            let dy1 = delta1Gen.dy
            let dx2 = delta2Gen.dx
            let dy2 = delta2Gen.dy
            
            self.mockContext.reset()
            
            let script = Script(name: "test", source: """
                mouseMove(\(dx1), \(dy1))
                mouseMove(\(dx2), \(dy2))
                """)
            
            let expectation = XCTestExpectation(description: "Script execution")
            Task {
                try? await self.scriptEngine.execute(script, context: self.mockContext)
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 2.0)
            
            // Verify both movements were emitted in order with exact values
            return self.mockContext.mouseMoves.count == 2
                && self.mockContext.mouseMoves[0].dx == dx1
                && self.mockContext.mouseMoves[0].dy == dy1
                && self.mockContext.mouseMoves[1].dx == dx2
                && self.mockContext.mouseMoves[1].dy == dy2
        }
    }
    
    /// Property 13.5: mouseMove preserves sign of delta values
    func testMouseMovePreservesSignOfDeltaValues() {
        property("mouseMove preserves sign of delta values") <- forAll { (deltaGen: MouseDeltaGenerator) in
            let dx = deltaGen.dx
            let dy = deltaGen.dy
            self.mockContext.reset()
            
            let script = Script(name: "test", source: "mouseMove(\(dx), \(dy))")
            
            let expectation = XCTestExpectation(description: "Script execution")
            Task {
                try? await self.scriptEngine.execute(script, context: self.mockContext)
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 1.0)
            
            guard self.mockContext.mouseMoves.count == 1 else { return false }
            
            let emittedDx = self.mockContext.mouseMoves[0].dx
            let emittedDy = self.mockContext.mouseMoves[0].dy
            
            // Verify signs are preserved
            let dxSignPreserved = (dx >= 0 && emittedDx >= 0) || (dx < 0 && emittedDx < 0)
            let dySignPreserved = (dy >= 0 && emittedDy >= 0) || (dy < 0 && emittedDy < 0)
            
            return dxSignPreserved && dySignPreserved
        }
    }
}
