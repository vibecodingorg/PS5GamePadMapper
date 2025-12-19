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
/// Requirements: 2.2, 4.4, 5.3, 5.4, 7.3 - Direction mapping support
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
    
    /// Track direction key states for direction-to-key mapping
    /// Requirements: 2.4 - Track direction states for release events
    private var directionKeyStates: [StickType: [StickDirection: Bool]] = [:]
    
    /// Track which sticks have direction mappings configured
    /// Requirements: 7.3 - Direction mappings take priority over axis
    private var sticksWithDirectionMappings: Set<StickType> = []
    
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
    public func handleButtonEvent(_ event: ButtonEvent) -> [ActionResult] {
        guard let profile = activeProfile else {
            print("[DEBUG] MappingEngine: No active profile")
            return []
        }
        
        var results: [ActionResult] = []
        
        // Find all mappings for this button
        let buttonMappings = profile.mappings.filter { mapping in
            if case .button(let buttonType) = mapping.input {
                return buttonType == event.button
            }
            return false
        }
        
        print("[DEBUG] MappingEngine: Found \(buttonMappings.count) mappings for button \(event.button.rawValue)")
        
        for mapping in buttonMappings {
            print("[DEBUG] MappingEngine: Checking mapping - trigger: \(mapping.trigger), action: \(mapping.action)")
            
            // Special handling for toggle mode
            if case .toggle = mapping.trigger {
                if case .pressed = event.state {
                    // Toggle the state
                    let currentState = toggleStates[event.button] ?? false
                    let newState = !currentState
                    toggleStates[event.button] = newState
                    
                    print("[DEBUG] MappingEngine: 🔄 Toggle state changed: \(currentState) -> \(newState)")
                    
                    // For key actions, send keyDown when toggling ON, keyUp when toggling OFF
                    if case .keyPress(let keyAction) = mapping.action {
                        if newState {
                            // Toggling ON - send keyDown (key stays pressed with repeat)
                            print("[DEBUG] MappingEngine: ✅ Toggle ON - sending keyPress (hold)")
                            results.append(ActionResult(action: .keyPress(keyAction), isToggleHold: true))
                        } else {
                            // Toggling OFF - send keyUp (release key)
                            print("[DEBUG] MappingEngine: ✅ Toggle OFF - sending keyRelease")
                            results.append(ActionResult(action: .keyRelease(keyAction), isToggleHold: false))
                        }
                    } else {
                        // For non-key actions, just execute on toggle ON
                        if newState {
                            results.append(ActionResult(action: mapping.action, isToggleHold: false))
                        }
                    }
                }
                continue
            }
            
            // Normal trigger evaluation for non-toggle modes
            if evaluateTrigger(mapping.trigger, for: event, button: event.button) != nil {
                print("[DEBUG] MappingEngine: ✅ Trigger matched! Adding action: \(mapping.action)")
                results.append(ActionResult(action: mapping.action, isToggleHold: false))
            } else {
                print("[DEBUG] MappingEngine: ❌ Trigger not matched for event state: \(event.state)")
            }
        }
        
        return results
    }
    
    /// Handle an axis event and return resulting actions
    /// Requirements: 7.1, 7.2, 7.3 - Axis-to-key threshold behavior
    /// Requirements: 7.3 - Direction mappings take priority over axis
    public func handleAxisEvent(_ event: AxisEvent) -> [Action] {
        guard let profile = activeProfile else { return [] }
        
        // Requirements: 7.3 - Check if this axis belongs to a stick with direction mappings
        // If so, skip axis processing to let direction mappings take priority
        let stickType = stickTypeForAxis(event.axis)
        if let stick = stickType, hasDirectionMappings(for: stick) {
            return []
        }
        
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
    
    // MARK: - Direction Handling
    
    /// Handle a direction event and return resulting actions
    /// Requirements: 2.2, 5.2 - Find direction mappings and execute actions
    /// Requirements: 4.4, 5.3 - Diagonal fallback to adjacent cardinals
    /// Requirements: 5.4 - Diagonal priority over cardinals
    public func handleDirectionEvent(_ event: DirectionEvent) -> [Action] {
        guard let profile = activeProfile else { return [] }
        
        var actions: [Action] = []
        
        // Find direct mapping for this direction
        let directMapping = findDirectionMapping(stick: event.stick, direction: event.direction, in: profile)
        
        if event.direction.isDiagonal {
            // Requirements: 5.4 - When diagonal has mapping, trigger only diagonal
            if let mapping = directMapping {
                if let action = processDirectionMapping(mapping, state: event.state, stick: event.stick, direction: event.direction) {
                    actions.append(action)
                }
            } else {
                // Requirements: 4.4, 5.3 - When diagonal has no mapping, trigger adjacent cardinals
                let fallbackActions = handleDiagonalFallback(
                    stick: event.stick,
                    direction: event.direction,
                    state: event.state,
                    profile: profile
                )
                actions.append(contentsOf: fallbackActions)
            }
        } else {
            // Cardinal direction - process directly
            if let mapping = directMapping {
                if let action = processDirectionMapping(mapping, state: event.state, stick: event.stick, direction: event.direction) {
                    actions.append(action)
                }
            }
        }
        
        return actions
    }
    
    /// Find a direction mapping for a specific stick and direction
    /// Requirements: 2.2 - Find direction mappings
    public func findDirectionMapping(stick: StickType, direction: StickDirection, in profile: Profile) -> Mapping? {
        return profile.mappings.first { mapping in
            if case .direction(let dirInput) = mapping.input {
                return dirInput.stick == stick && dirInput.direction == direction
            }
            return false
        }
    }
    
    /// Handle diagonal fallback to adjacent cardinal directions
    /// Requirements: 4.4, 5.3 - When diagonal has no mapping, trigger both adjacent cardinals
    public func handleDiagonalFallback(stick: StickType, direction: StickDirection, state: DirectionState, profile: Profile) -> [Action] {
        guard direction.isDiagonal else { return [] }
        
        var actions: [Action] = []
        
        // Get adjacent cardinal directions
        let adjacentCardinals = direction.adjacentCardinals
        
        for cardinal in adjacentCardinals {
            if let mapping = findDirectionMapping(stick: stick, direction: cardinal, in: profile) {
                if let action = processDirectionMapping(mapping, state: state, stick: stick, direction: cardinal) {
                    actions.append(action)
                }
            }
        }
        
        return actions
    }
    
    /// Process a direction mapping based on state
    /// Requirements: 2.2 - Execute corresponding actions
    private func processDirectionMapping(_ mapping: Mapping, state: DirectionState, stick: StickType, direction: StickDirection) -> Action? {
        // Initialize direction state tracking if needed
        if directionKeyStates[stick] == nil {
            directionKeyStates[stick] = [:]
        }
        
        let wasPressed = directionKeyStates[stick]?[direction] ?? false
        
        switch state {
        case .pressed:
            if !wasPressed {
                directionKeyStates[stick]?[direction] = true
                // Return press action based on trigger mode
                if case .press = mapping.trigger {
                    return mapping.action
                } else if case .toggle = mapping.trigger {
                    return mapping.action
                }
            }
            
        case .released:
            if wasPressed {
                directionKeyStates[stick]?[direction] = false
                // Return release action based on trigger mode
                if case .release = mapping.trigger {
                    return mapping.action
                }
                // For key press actions, emit key release
                if case .press = mapping.trigger {
                    if case .keyPress(let keyAction) = mapping.action {
                        return .keyRelease(keyAction)
                    }
                }
            }
            
        case .held:
            // For hold trigger mode, check if threshold is met
            if case .hold = mapping.trigger {
                return mapping.action
            }
        }
        
        return nil
    }
    
    /// Check if a stick has any direction mappings configured
    /// Requirements: 7.3 - Direction mappings take priority over axis
    public func hasDirectionMappings(for stick: StickType) -> Bool {
        guard let profile = activeProfile else { return false }
        
        return profile.mappings.contains { mapping in
            if case .direction(let dirInput) = mapping.input {
                return dirInput.stick == stick
            }
            return false
        }
    }
    
    /// Get the stick type for an axis, if applicable
    /// Requirements: 7.3 - Map axis to stick for priority checking
    private func stickTypeForAxis(_ axis: AxisType) -> StickType? {
        switch axis {
        case .leftStickX, .leftStickY:
            return .left
        case .rightStickX, .rightStickY:
            return .right
        case .l2Trigger, .r2Trigger:
            return nil
        }
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
            // Toggle state on press - handled specially, always return true on press
            // The actual toggle logic (keyDown vs keyUp) is handled in handleButtonEvent
            if case .pressed = event.state {
                return true
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
    
    /// Reset all direction states
    /// Requirements: 2.4 - Reset direction tracking
    public func resetDirectionStates() {
        directionKeyStates.removeAll()
    }
    
    /// Get the current direction state for a stick and direction
    public func getDirectionState(for stick: StickType, direction: StickDirection) -> Bool {
        return directionKeyStates[stick]?[direction] ?? false
    }
}

// MARK: - Supporting Types

/// Result of processing a button event, includes the action and whether it should use hold mode
public struct ActionResult {
    public let action: Action
    /// If true, the key should be held down continuously (for toggle mode)
    public let isToggleHold: Bool
    
    public init(action: Action, isToggleHold: Bool) {
        self.action = action
        self.isToggleHold = isToggleHold
    }
}

/// Tracks the current key press state for axis-to-key mapping
public struct AxisKeyState: Equatable {
    public var positivePressed: Bool = false
    public var negativePressed: Bool = false
    
    public init(positivePressed: Bool = false, negativePressed: Bool = false) {
        self.positivePressed = positivePressed
        self.negativePressed = negativePressed
    }
}
