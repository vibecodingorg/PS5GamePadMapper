import Foundation
import CoreGraphics

/// Protocol for emitting system events
/// Requirements: 4.1, 4.2, 4.3, 4.4, 5.1, 6.1
public protocol EventEmitterProtocol {
    /// Emit a key down event
    func emitKeyDown(_ keyCode: UInt16, modifiers: KeyModifiers)
    
    /// Emit a key up event
    func emitKeyUp(_ keyCode: UInt16, modifiers: KeyModifiers)
    
    /// Emit a mouse button down event
    func emitMouseDown(_ button: MouseButton)
    
    /// Emit a mouse button up event
    func emitMouseUp(_ button: MouseButton)
    
    /// Emit a relative mouse movement
    func emitMouseMove(dx: CGFloat, dy: CGFloat)
    
    /// Emit a mouse scroll event
    func emitMouseScroll(dx: CGFloat, dy: CGFloat)
}
