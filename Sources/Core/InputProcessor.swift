import Foundation

/// Input processor implementation for normalizing and processing controller inputs
/// Requirements: 3.2, 3.4, 6.4
public final class InputProcessor: InputProcessorProtocol {
    
    // Track button press timestamps for hold duration calculation
    private var buttonPressTimestamps: [ButtonType: UInt64] = [:]
    
    public init() {}
    
    // MARK: - InputProcessorProtocol
    
    /// Process a raw button input into a button event
    public func processButtonInput(_ input: RawButtonInput) -> ButtonEvent {
        if input.isPressed {
            // Record press timestamp
            buttonPressTimestamps[input.button] = input.timestamp
            return ButtonEvent(button: input.button, state: .pressed, holdDuration: nil)
        } else {
            // Calculate hold duration if we have a press timestamp
            var holdDuration: TimeInterval? = nil
            if let pressTimestamp = buttonPressTimestamps[input.button] {
                // Convert from nanoseconds to seconds
                holdDuration = Double(input.timestamp - pressTimestamp) / 1_000_000_000.0
                buttonPressTimestamps.removeValue(forKey: input.button)
            }
            return ButtonEvent(button: input.button, state: .released, holdDuration: holdDuration)
        }
    }
    
    /// Process a raw axis input into an axis event with normalization and deadzone
    /// Requirements: 3.2 - Normalize values to -1.0 to 1.0 for sticks, 0.0 to 1.0 for triggers
    /// Requirements: 3.4 - Treat values within deadzone as zero
    /// Requirements: 6.4 - Support linear and exponential response curves
    public func processAxisInput(_ input: RawAxisInput, config: AxisConfig) -> AxisEvent {
        // Step 1: Normalize raw value to standard range
        let normalizedValue = normalizeAxisValue(input.rawValue, axis: input.axis)
        
        // Step 2: Apply deadzone processing
        let deadzoneProcessed = applyDeadzone(normalizedValue, deadzone: config.deadzone, isTrigger: input.axis.isTrigger)
        
        // Step 3: Apply response curve
        let curveApplied = applyResponseCurve(deadzoneProcessed, curve: config.curve, isTrigger: input.axis.isTrigger)
        
        // Step 4: Apply sensitivity
        let finalValue = applySensitivity(curveApplied, sensitivity: config.sensitivity, isTrigger: input.axis.isTrigger)
        
        return AxisEvent(axis: input.axis, normalizedValue: finalValue)
    }
    
    // MARK: - Axis Processing Helpers
    
    /// Normalize raw axis value to standard range
    /// Sticks: -1.0 to 1.0 (from Int16 range -32768 to 32767)
    /// Triggers: 0.0 to 1.0 (from 0 to 255)
    internal func normalizeAxisValue(_ rawValue: Int16, axis: AxisType) -> Double {
        if axis.isTrigger {
            // Triggers use 0-255 range, normalize to 0.0-1.0
            let clampedValue = max(0, min(255, Int(rawValue)))
            return Double(clampedValue) / 255.0
        } else {
            // Sticks use -32768 to 32767 range, normalize to -1.0 to 1.0
            if rawValue >= 0 {
                return Double(rawValue) / 32767.0
            } else {
                return Double(rawValue) / 32768.0
            }
        }
    }
    
    /// Apply deadzone processing
    /// Values within deadzone are treated as zero
    /// Values outside deadzone are rescaled to use full range
    internal func applyDeadzone(_ value: Double, deadzone: Double, isTrigger: Bool) -> Double {
        if isTrigger {
            // Trigger: 0.0 to 1.0 range
            if value <= deadzone {
                return 0.0
            }
            // Rescale remaining range to 0.0-1.0
            return (value - deadzone) / (1.0 - deadzone)
        } else {
            // Stick: -1.0 to 1.0 range
            let absValue = abs(value)
            if absValue <= deadzone {
                return 0.0
            }
            // Rescale remaining range, preserving sign
            let sign = value >= 0 ? 1.0 : -1.0
            return sign * (absValue - deadzone) / (1.0 - deadzone)
        }
    }
    
    /// Apply response curve transformation
    internal func applyResponseCurve(_ value: Double, curve: ResponseCurve, isTrigger: Bool) -> Double {
        switch curve {
        case .linear:
            return value
        case .exponential(let power):
            if isTrigger {
                // Trigger: apply power directly (value is 0.0 to 1.0)
                return pow(value, power)
            } else {
                // Stick: preserve sign, apply power to magnitude
                let sign = value >= 0 ? 1.0 : -1.0
                return sign * pow(abs(value), power)
            }
        }
    }
    
    /// Apply sensitivity multiplier
    /// Clamps output to valid range
    internal func applySensitivity(_ value: Double, sensitivity: Double, isTrigger: Bool) -> Double {
        let scaled = value * sensitivity
        if isTrigger {
            return max(0.0, min(1.0, scaled))
        } else {
            return max(-1.0, min(1.0, scaled))
        }
    }
}
