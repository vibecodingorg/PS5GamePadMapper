import Foundation

/// Configuration for axis-to-key mapping
/// Requirements: 7.4 - Configurable activation threshold
public struct AxisToKeyConfig: Codable, Equatable {
    /// The key to press when axis exceeds positive threshold
    public let positiveKey: KeyAction?
    /// The key to press when axis exceeds negative threshold
    public let negativeKey: KeyAction?
    /// Activation threshold (0.1 to 0.9)
    public let threshold: Double
    
    public static let thresholdRange: ClosedRange<Double> = 0.1...0.9
    
    public init(positiveKey: KeyAction?, negativeKey: KeyAction?, threshold: Double = 0.5) {
        self.positiveKey = positiveKey
        self.negativeKey = negativeKey
        self.threshold = max(0.1, min(0.9, threshold))
    }
}

/// Core mapping engine that converts controller inputs to actions
/// Requirements: 4.5, 5.2, 5.3, 5.4, 7.1, 7.2, 7.3, 7.4
public final class MappingEngine: MappingEngineProtocol {
    
    // MARK: - Properties
    
    public var activeProfile: Profile?
    
    /// Track button states for toggle mode
    private var toggleStates: [ButtonType: Bool] = [:]
    
    /// Track button press timestamps for hold detection
    private var buttonPressTimestamps: [ButtonType: Date] = [:]
    
    /// Track axis key states for axis-to-key mapping
    private var axisKeyStates: [AxisType: AxisKeyState] = [:]
    
    /// Axis-to-key configurations
    private var axisToKeyConfigs: [AxisType: AxisToKeyConfig] = [:]
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Configuration
    
    /// Configure axis-to-key mapping for a specific axis
    /// Requirements: 7.4 - Configurable activation threshold
    public func setAxisToKeyConfig(_ config: AxisToKeyConfig, for axis: AxisType) {
        axisToKeyConfigs[axis] = config
    }
    
    /// Get the axis-to-key configuration for a specific axis
    public func getAxisToKeyConfig(for axis: AxisType) -> AxisToKeyConfig? {
        return axisToKeyConfigs[axis]
    }
    
    /// Clear all axis-to-key configurations
    public func clearAxisToKeyConfigs() {
        axisToKeyConfigs.removeAll()
        axisKeyStates.removeAll()
    }

    
    // MARK: - MappingEngineProtocol
    
    /// Handle a button event and return resulting actions
    /// Requirements: 4.5 - Support Press, Release, and Hold trigger types
    /// Requirements: 5.2, 5.3, 5.4 - Mouse button and scroll mapping
    public func handleButtonEvent(_ event: ButtonEvent) -> [Action] {
        guard let profile = activeProfile else { return [] }
        
        var actions: [Action] = []
        
        // Find all mappings for this button
        let buttonMappings = profile.mappings.filter { mapping in
            if case .button(let buttonType) = mapping.input {
                return buttonType == event.button
            }
            return false
        }
        
        for mapping in buttonMappings {
            if evaluateTrigger(mapping.trigger, for: event, button: event.button) != nil {
                actions.append(mapping.action)
            }
        }
        
        return actions
    }
    
    /// Handle an axis event and return resulting actions
    /// Requirements: 7.1, 7.2, 7.3 - Axis-to-key threshold behavior
    public func handleAxisEvent(_ event: AxisEvent) -> [Action] {
        guard let profile = activeProfile else { return [] }
        
        var actions: [Action] = []
        
        // Find all mappings for this axis
        let axisMappings = profile.mappings.filter { mapping in
            if case .axis(let axisType) = mapping.input {
                return axisType == event.axis
            }
            return false
        }
        
        for mapping in axisMappings {
            // For axis mappings, we typically return the action directly
            // The action itself contains the configuration (e.g., MouseMoveAction with sensitivity)
            actions.append(mapping.action)
        }
        
        // Handle axis-to-key mappings
        if let keyActions = processAxisToKey(event) {
            actions.append(contentsOf: keyActions)
        }
        
        return actions
    }
    
    // MARK: - Private Methods
    
    /// Evaluate if a trigger condition is met for a button event
    /// Returns true if the trigger condition is satisfied
    private func evaluateTrigger(_ trigger: TriggerMode, for event: ButtonEvent, button: ButtonType) -> Bool? {
        switch trigger {
        case .press:
            // Trigger on button press
            if case .pressed = event.state {
                return true
            }
            
        case .release:
            // Trigger on button release
            if case .released = event.state {
                return true
            }
            
        case .hold(let threshold):
            // Trigger when held for specified duration
            if case .held(let duration) = event.state {
                if duration >= threshold {
                    return true
                }
            }
            
        case .toggle:
            // Toggle state on press
            if case .pressed = event.state {
                let currentState = toggleStates[button] ?? false
                toggleStates[button] = !currentState
                // Only trigger action when toggling ON
                if !currentState {
                    return true
                }
            }
        }
        
        return nil
    }

    
    /// Process axis-to-key mapping
    /// Requirements: 7.1, 7.2, 7.3 - Threshold-based key press/release
    private func processAxisToKey(_ event: AxisEvent) -> [Action]? {
        guard let config = axisToKeyConfigs[event.axis] else { return nil }
        
        var actions: [Action] = []
        let currentState = axisKeyStates[event.axis] ?? AxisKeyState()
        var newState = currentState
        
        let value = event.normalizedValue
        let threshold = config.threshold
        
        // Check positive direction
        // Requirements: 7.1 - When axis exceeds positive threshold, emit positive key press
        if value >= threshold {
            if !currentState.positivePressed, let positiveKey = config.positiveKey {
                actions.append(.keyPress(positiveKey))
                newState.positivePressed = true
            }
        } else {
            // Requirements: 7.3 - When axis returns below threshold, emit key release
            if currentState.positivePressed, let positiveKey = config.positiveKey {
                actions.append(.keyRelease(positiveKey))
                newState.positivePressed = false
            }
        }
        
        // Check negative direction (only for stick axes, not triggers)
        // Requirements: 7.2 - When axis exceeds negative threshold, emit negative key press
        if !event.axis.isTrigger {
            if value <= -threshold {
                if !currentState.negativePressed, let negativeKey = config.negativeKey {
                    actions.append(.keyPress(negativeKey))
                    newState.negativePressed = true
                }
            } else {
                // Requirements: 7.3 - When axis returns below threshold, emit key release
                if currentState.negativePressed, let negativeKey = config.negativeKey {
                    actions.append(.keyRelease(negativeKey))
                    newState.negativePressed = false
                }
            }
        }
        
        axisKeyStates[event.axis] = newState
        
        return actions.isEmpty ? nil : actions
    }
    
    // MARK: - State Management
    
    /// Reset all toggle states
    public func resetToggleStates() {
        toggleStates.removeAll()
    }
    
    /// Get the current toggle state for a button
    public func getToggleState(for button: ButtonType) -> Bool {
        return toggleStates[button] ?? false
    }
    
    /// Get the current axis key state for an axis
    public func getAxisKeyState(for axis: AxisType) -> AxisKeyState {
        return axisKeyStates[axis] ?? AxisKeyState()
    }
}

// MARK: - Supporting Types

/// Tracks the current key press state for axis-to-key mapping
public struct AxisKeyState: Equatable {
    public var positivePressed: Bool = false
    public var negativePressed: Bool = false
    
    public init(positivePressed: Bool = false, negativePressed: Bool = false) {
        self.positivePressed = positivePressed
        self.negativePressed = negativePressed
    }
}
