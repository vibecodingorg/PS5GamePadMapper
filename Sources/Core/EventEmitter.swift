import Foundation
import CoreGraphics
import Carbon.HIToolbox

/// Event emitter that uses CGEventPost to emit keyboard and mouse events
/// Requirements: 4.1, 4.2, 5.1, 6.1
public final class EventEmitter: EventEmitterProtocol {
    
    /// The event source for creating events
    private let eventSource: CGEventSource?
    
    /// Track which modifier keys are currently pressed (for proper release)
    private var activeModifiers: KeyModifiers = []
    
    /// Ordered list of emitted events for testing/debugging
    public private(set) var emittedEvents: [EmittedEvent] = []
    
    /// Whether to record events (for testing)
    public var recordEvents: Bool = false
    
    public init() {
        self.eventSource = CGEventSource(stateID: .hidSystemState)
    }
    
    // MARK: - Keyboard Events
    
    /// Emit a key down event with modifiers
    /// Requirements: 4.1 - Emit keyboard key press event within 20ms
    /// Requirements: 4.4 - Emit all modifier keys before the primary key
    public func emitKeyDown(_ keyCode: UInt16, modifiers: KeyModifiers) {
        print("[DEBUG] EventEmitter: ⌨️ emitKeyDown - keyCode: \(keyCode), modifiers: \(modifiers)")
        
        // First, emit modifier keys in order (Cmd, Ctrl, Alt, Shift)
        let orderedMods = modifiers.orderedModifiers
        for modifier in orderedMods {
            if !activeModifiers.contains(modifier) {
                emitModifierKeyDown(modifier)
                activeModifiers.insert(modifier)
            }
        }
        
        // Then emit the primary key
        emitKeyEvent(keyCode: keyCode, keyDown: true, modifiers: modifiers)
        print("[DEBUG] EventEmitter: ✅ Key down event posted")
        
        if recordEvents {
            emittedEvents.append(.keyDown(keyCode: keyCode, modifiers: modifiers))
        }
    }
    
    /// Emit a key up event with modifiers
    /// Requirements: 4.2 - Emit keyboard key release event within 20ms
    public func emitKeyUp(_ keyCode: UInt16, modifiers: KeyModifiers) {
        print("[DEBUG] EventEmitter: ⌨️ emitKeyUp - keyCode: \(keyCode), modifiers: \(modifiers)")
        
        // First release the primary key
        emitKeyEvent(keyCode: keyCode, keyDown: false, modifiers: modifiers)
        print("[DEBUG] EventEmitter: ✅ Key up event posted")
        
        if recordEvents {
            emittedEvents.append(.keyUp(keyCode: keyCode, modifiers: modifiers))
        }
        
        // Then release modifier keys in reverse order
        let orderedMods = modifiers.orderedModifiers.reversed()
        for modifier in orderedMods {
            if activeModifiers.contains(modifier) {
                emitModifierKeyUp(modifier)
                activeModifiers.remove(modifier)
            }
        }
    }

    
    // MARK: - Mouse Button Events
    
    /// Emit a mouse button down event
    /// Requirements: 5.1 - Emit mouse button event within 20ms
    public func emitMouseDown(_ button: MouseButton) {
        let eventType = mouseDownEventType(for: button)
        let mouseButton = cgMouseButton(for: button)
        
        if let event = CGEvent(mouseEventSource: eventSource,
                               mouseType: eventType,
                               mouseCursorPosition: currentMouseLocation(),
                               mouseButton: mouseButton) {
            event.post(tap: .cghidEventTap)
        }
        
        if recordEvents {
            emittedEvents.append(.mouseDown(button: button))
        }
    }
    
    /// Emit a mouse button up event
    /// Requirements: 5.1 - Emit mouse button event within 20ms
    public func emitMouseUp(_ button: MouseButton) {
        let eventType = mouseUpEventType(for: button)
        let mouseButton = cgMouseButton(for: button)
        
        if let event = CGEvent(mouseEventSource: eventSource,
                               mouseType: eventType,
                               mouseCursorPosition: currentMouseLocation(),
                               mouseButton: mouseButton) {
            event.post(tap: .cghidEventTap)
        }
        
        if recordEvents {
            emittedEvents.append(.mouseUp(button: button))
        }
    }
    
    // MARK: - Mouse Movement
    
    /// Emit a relative mouse movement event
    /// Requirements: 6.1 - Emit continuous mouse movement events
    public func emitMouseMove(dx: CGFloat, dy: CGFloat) {
        let currentPos = currentMouseLocation()
        let newPos = CGPoint(x: currentPos.x + dx, y: currentPos.y + dy)
        
        if let event = CGEvent(mouseEventSource: eventSource,
                               mouseType: .mouseMoved,
                               mouseCursorPosition: newPos,
                               mouseButton: .left) {
            event.post(tap: .cghidEventTap)
        }
        
        if recordEvents {
            emittedEvents.append(.mouseMove(dx: dx, dy: dy))
        }
    }
    
    // MARK: - Mouse Scroll
    
    /// Emit a mouse scroll event
    /// Requirements: 5.3, 5.4 - Emit scroll events with configurable amount and direction
    public func emitMouseScroll(dx: CGFloat, dy: CGFloat) {
        // CGEvent scroll uses wheel units (positive = up/left, negative = down/right)
        let scrollY = Int32(dy)
        let scrollX = Int32(dx)
        
        if let event = CGEvent(scrollWheelEvent2Source: eventSource,
                               units: .pixel,
                               wheelCount: 2,
                               wheel1: scrollY,
                               wheel2: scrollX,
                               wheel3: 0) {
            event.post(tap: .cghidEventTap)
        }
        
        if recordEvents {
            emittedEvents.append(.mouseScroll(dx: dx, dy: dy))
        }
    }

    
    // MARK: - Private Helpers
    
    private func emitKeyEvent(keyCode: UInt16, keyDown: Bool, modifiers: KeyModifiers) {
        if let event = CGEvent(keyboardEventSource: eventSource,
                               virtualKey: CGKeyCode(keyCode),
                               keyDown: keyDown) {
            // Set modifier flags on the event
            var flags: CGEventFlags = []
            if modifiers.contains(.command) { flags.insert(.maskCommand) }
            if modifiers.contains(.control) { flags.insert(.maskControl) }
            if modifiers.contains(.option) { flags.insert(.maskAlternate) }
            if modifiers.contains(.shift) { flags.insert(.maskShift) }
            event.flags = flags
            
            event.post(tap: .cghidEventTap)
        }
    }
    
    private func emitModifierKeyDown(_ modifier: KeyModifiers) {
        let keyCode = modifierKeyCode(for: modifier)
        if let event = CGEvent(keyboardEventSource: eventSource,
                               virtualKey: CGKeyCode(keyCode),
                               keyDown: true) {
            event.post(tap: .cghidEventTap)
        }
        
        if recordEvents {
            emittedEvents.append(.modifierDown(modifier: modifier))
        }
    }
    
    private func emitModifierKeyUp(_ modifier: KeyModifiers) {
        let keyCode = modifierKeyCode(for: modifier)
        if let event = CGEvent(keyboardEventSource: eventSource,
                               virtualKey: CGKeyCode(keyCode),
                               keyDown: false) {
            event.post(tap: .cghidEventTap)
        }
        
        if recordEvents {
            emittedEvents.append(.modifierUp(modifier: modifier))
        }
    }
    
    private func modifierKeyCode(for modifier: KeyModifiers) -> UInt16 {
        switch modifier {
        case .command: return UInt16(kVK_Command)
        case .control: return UInt16(kVK_Control)
        case .option: return UInt16(kVK_Option)
        case .shift: return UInt16(kVK_Shift)
        default: return 0
        }
    }
    
    private func mouseDownEventType(for button: MouseButton) -> CGEventType {
        switch button {
        case .left: return .leftMouseDown
        case .right: return .rightMouseDown
        case .middle: return .otherMouseDown
        }
    }
    
    private func mouseUpEventType(for button: MouseButton) -> CGEventType {
        switch button {
        case .left: return .leftMouseUp
        case .right: return .rightMouseUp
        case .middle: return .otherMouseUp
        }
    }
    
    private func cgMouseButton(for button: MouseButton) -> CGMouseButton {
        switch button {
        case .left: return .left
        case .right: return .right
        case .middle: return .center
        }
    }
    
    private func currentMouseLocation() -> CGPoint {
        return CGEvent(source: nil)?.location ?? .zero
    }
    
    // MARK: - Convenience Methods
    
    /// Emit a complete key tap (down + up) with modifiers
    /// This ensures modifiers are properly pressed before and released after the key
    public func emitKeyTap(_ keyCode: UInt16, modifiers: KeyModifiers) {
        emitKeyDown(keyCode, modifiers: modifiers)
        emitKeyUp(keyCode, modifiers: modifiers)
    }
    
    /// Emit a complete mouse click (down + up)
    public func emitMouseClick(_ button: MouseButton) {
        emitMouseDown(button)
        emitMouseUp(button)
    }
    
    // MARK: - Testing Support
    
    /// Clear recorded events and reset state
    public func clearRecordedEvents() {
        emittedEvents.removeAll()
        activeModifiers = []
    }
    
    /// Reset all state (for testing)
    public func reset() {
        emittedEvents.removeAll()
        activeModifiers = []
    }
    
    /// Get the order of modifier events emitted for a key down
    /// This is useful for testing Property 3: Modifier Key Ordering
    public func getModifierOrder(from events: [EmittedEvent]) -> [KeyModifiers] {
        return events.compactMap { event in
            if case .modifierDown(let modifier) = event {
                return modifier
            }
            return nil
        }
    }
}

// MARK: - Emitted Event Type (for testing/debugging)

/// Represents an emitted event for testing and debugging purposes
public enum EmittedEvent: Equatable {
    case keyDown(keyCode: UInt16, modifiers: KeyModifiers)
    case keyUp(keyCode: UInt16, modifiers: KeyModifiers)
    case modifierDown(modifier: KeyModifiers)
    case modifierUp(modifier: KeyModifiers)
    case mouseDown(button: MouseButton)
    case mouseUp(button: MouseButton)
    case mouseMove(dx: CGFloat, dy: CGFloat)
    case mouseScroll(dx: CGFloat, dy: CGFloat)
}
