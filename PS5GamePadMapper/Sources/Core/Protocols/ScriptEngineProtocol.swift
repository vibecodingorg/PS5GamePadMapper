import Foundation

/// Protocol for script execution context
/// Requirements: 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8
public protocol ScriptContext {
    /// Emit a key press event
    func pressKey(_ key: String)
    
    /// Emit a key release event
    func releaseKey(_ key: String)
    
    /// Emit a key tap (press + delay + release)
    func tapKey(_ key: String, duration: Int)
    
    /// Emit a mouse click
    func mouseClick(_ button: String)
    
    /// Emit a relative mouse movement
    func mouseMove(dx: Int, dy: Int)
    
    /// Pause execution for specified milliseconds
    func sleep(_ milliseconds: Int) async
    
    /// Query if a controller button is currently pressed
    func isButtonPressed(_ button: String) -> Bool
}

/// Protocol for script execution engine
/// Requirements: 12.1
public protocol ScriptEngineProtocol {
    /// Execute a script in the given context
    func execute(_ script: Script, context: ScriptContext) async throws
}
