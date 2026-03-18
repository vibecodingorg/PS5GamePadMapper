import Foundation

/// Response curve types for axis input
/// Requirements: 6.4 - Support linear and exponential response curves
public enum ResponseCurve: Codable, Equatable {
    case linear
    case exponential(power: Double)
}

/// Validation error for axis configuration parameters
/// Requirements: 6.2, 6.3 - Parameter validation
public enum AxisConfigValidationError: Error, Equatable {
    case invalidDeadzone(value: Double)
    case invalidSensitivity(value: Double)
    
    public var localizedDescription: String {
        switch self {
        case .invalidDeadzone(let value):
            return "Deadzone \(value) is outside valid range 0.0 to 0.5"
        case .invalidSensitivity(let value):
            return "Sensitivity \(value) is outside valid range 0.1 to 10.0"
        }
    }
}

/// Configuration for axis input processing
/// Requirements: 6.2, 6.3 - Configurable sensitivity and deadzone
public struct AxisConfig: Codable, Equatable {
    
    /// Valid range for deadzone parameter
    public static let deadzoneRange: ClosedRange<Double> = 0.0...0.5
    
    /// Valid range for sensitivity parameter
    public static let sensitivityRange: ClosedRange<Double> = 0.1...10.0
    
    /// Deadzone threshold (0.0 to 0.5)
    public let deadzone: Double
    
    /// Sensitivity multiplier (0.1 to 10.0)
    public let sensitivity: Double
    
    /// Response curve type
    public let curve: ResponseCurve
    
    public init(deadzone: Double = 0.1, sensitivity: Double = 1.0, curve: ResponseCurve = .linear) {
        self.deadzone = deadzone
        self.sensitivity = sensitivity
        self.curve = curve
    }
    
    /// Creates a validated AxisConfig, throwing an error if parameters are invalid
    /// Requirements: 6.2, 6.3 - Validate sensitivity and deadzone ranges
    public static func validated(
        deadzone: Double,
        sensitivity: Double,
        curve: ResponseCurve = .linear
    ) throws -> AxisConfig {
        if let error = validateDeadzone(deadzone) {
            throw error
        }
        if let error = validateSensitivity(sensitivity) {
            throw error
        }
        return AxisConfig(deadzone: deadzone, sensitivity: sensitivity, curve: curve)
    }
    
    /// Validates a deadzone value
    /// Returns nil if valid, or an error if invalid
    /// Requirements: 6.3 - Deadzone range 0.0 to 0.5
    public static func validateDeadzone(_ value: Double) -> AxisConfigValidationError? {
        if !deadzoneRange.contains(value) {
            return .invalidDeadzone(value: value)
        }
        return nil
    }
    
    /// Validates a sensitivity value
    /// Returns nil if valid, or an error if invalid
    /// Requirements: 6.2 - Sensitivity range 0.1 to 10.0
    public static func validateSensitivity(_ value: Double) -> AxisConfigValidationError? {
        if !sensitivityRange.contains(value) {
            return .invalidSensitivity(value: value)
        }
        return nil
    }
    
    /// Validates the configuration parameters
    /// Returns nil if valid, or an error message if invalid
    public func validate() -> String? {
        if deadzone < 0.0 || deadzone > 0.5 {
            return "Deadzone must be between 0.0 and 0.5"
        }
        if sensitivity < 0.1 || sensitivity > 10.0 {
            return "Sensitivity must be between 0.1 and 10.0"
        }
        return nil
    }
    
    /// Returns true if this configuration has valid parameters
    public var isValid: Bool {
        return validate() == nil
    }
}
