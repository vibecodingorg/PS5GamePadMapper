import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Script API key events
/// **Feature: ps5-gamepad-mapper, Property 12: Script API Key Events**
final class ScriptAPIKeyEventsPropertyTests: XCTestCase {
    
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
    
    // MARK: - Property 12: Script API Key Events
    
    /// **Feature: ps5-gamepad-mapper, Property 12: Script API Key Events**
    /// **Validates: Requirements 12.2, 12.3, 12.4**
    ///
    /// *For any* key specified in script API calls:
    /// - pressKey(key) SHALL emit exactly one key down event for that key
    /// - releaseKey(key) SHALL emit exactly one key up event for that key
    /// - tapKey(key, ms) SHALL emit one key down event followed by one key up event
    
    /// Property 12.1: pressKey emits exactly one key press event
    func testPressKeyEmitsExactlyOneKeyPressEvent() {
        property("pressKey emits exactly one key press event") <- forAll { (keyGen: KeyNameGenerator) in
            let key = keyGen.value
            self.mockContext.reset()
            
            let script = Script(name: "test", source: "pressKey(\(key))")
            
            let expectation = XCTestExpectation(description: "Script execution")
            Task {
                try? await self.scriptEngine.execute(script, context: self.mockContext)
                expectation.fulfill()
            }
            
            // Wait for async execution
            _ = XCTWaiter.wait(for: [expectation], timeout: 1.0)
            
            // Verify exactly one key press was emitted for the specified key
            return self.mockContext.keyPresses.count == 1
                && self.mockContext.keyPresses[0] == key
        }
    }
    
    /// Property 12.2: releaseKey emits exactly one key release event
    func testReleaseKeyEmitsExactlyOneKeyReleaseEvent() {
        property("releaseKey emits exactly one key release event") <- forAll { (keyGen: KeyNameGenerator) in
            let key = keyGen.value
            self.mockContext.reset()
            
            let script = Script(name: "test", source: "releaseKey(\(key))")
            
            let expectation = XCTestExpectation(description: "Script execution")
            Task {
                try? await self.scriptEngine.execute(script, context: self.mockContext)
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 1.0)
            
            // Verify exactly one key release was emitted for the specified key
            return self.mockContext.keyReleases.count == 1
                && self.mockContext.keyReleases[0] == key
        }
    }

    
    /// Property 12.3: tapKey emits one key down followed by one key up
    func testTapKeyEmitsKeyDownThenKeyUp() {
        property("tapKey emits one key tap event") <- forAll { (keyGen: KeyNameGenerator, durationGen: DurationGenerator) in
            let key = keyGen.value
            let duration = durationGen.value
            self.mockContext.reset()
            
            let script = Script(name: "test", source: "tapKey(\(key), \(duration))")
            
            let expectation = XCTestExpectation(description: "Script execution")
            Task {
                try? await self.scriptEngine.execute(script, context: self.mockContext)
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 2.0)
            
            // Verify exactly one tap was recorded with correct key and duration
            return self.mockContext.keyTaps.count == 1
                && self.mockContext.keyTaps[0].key == key
                && self.mockContext.keyTaps[0].duration == duration
        }
    }
    
    /// Property 12.4: pressKey followed by releaseKey emits both events for same key
    func testPressKeyFollowedByReleaseKeyEmitsBothEvents() {
        property("pressKey followed by releaseKey emits both events for same key") <- forAll { (keyGen: KeyNameGenerator) in
            let key = keyGen.value
            self.mockContext.reset()
            
            let script = Script(name: "test", source: """
                pressKey(\(key))
                releaseKey(\(key))
                """)
            
            let expectation = XCTestExpectation(description: "Script execution")
            Task {
                try? await self.scriptEngine.execute(script, context: self.mockContext)
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 2.0)
            
            // Verify both press and release were emitted for the same key
            return self.mockContext.keyPresses.count == 1
                && self.mockContext.keyReleases.count == 1
                && self.mockContext.keyPresses[0] == key
                && self.mockContext.keyReleases[0] == key
        }
    }
    
    /// Property 12.5: Different keys can be pressed independently
    func testDifferentKeysCanBePressedIndependently() {
        property("Different keys can be pressed independently") <- forAll { (key1Gen: KeyNameGenerator, key2Gen: KeyNameGenerator) in
            let key1 = key1Gen.value
            let key2 = key2Gen.value
            
            self.mockContext.reset()
            
            let script = Script(name: "test", source: """
                pressKey(\(key1))
                pressKey(\(key2))
                """)
            
            let expectation = XCTestExpectation(description: "Script execution")
            Task {
                try? await self.scriptEngine.execute(script, context: self.mockContext)
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 2.0)
            
            // Verify both keys were pressed in order
            return self.mockContext.keyPresses.count == 2
                && self.mockContext.keyPresses[0] == key1
                && self.mockContext.keyPresses[1] == key2
        }
    }
}
