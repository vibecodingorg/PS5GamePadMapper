import Foundation

/// Utility for formatting axis values in the debug panel
/// Requirements: 15.4 - Show normalized value with 2 decimal precision
/// Requirements: 8.2, 8.3 - Show angle in degrees and magnitude
public struct DebugPanelAxisFormatter {
    
    /// Format an axis value with exactly 2 decimal places
    /// Requirements: 15.4 - Show normalized value with 2 decimal precision
    ///
    /// - Parameter value: The normalized axis value to format
    /// - Returns: A string representation with exactly 2 decimal places (e.g., "0.50", "-1.00")
    public static func formatAxisValue(_ value: Double) -> String {
        return String(format: "%.2f", value)
    }
    
    /// Format an angle value in degrees with 1 decimal place
    /// Requirements: 8.2 - Show the current angle in degrees
    ///
    /// - Parameter angle: The angle in degrees (0-360)
    /// - Returns: A string representation with 1 decimal place and degree symbol (e.g., "45.0°")
    public static func formatAngle(_ angle: Double) -> String {
        // Normalize angle to 0-360 range
        var normalizedAngle = angle.truncatingRemainder(dividingBy: 360.0)
        if normalizedAngle < 0 {
            normalizedAngle += 360.0
        }
        return String(format: "%.1f°", normalizedAngle)
    }
    
    /// Format a magnitude value with 2 decimal places
    /// Requirements: 8.3 - Show the current magnitude (0.0 to 1.0)
    ///
    /// - Parameter magnitude: The magnitude value (0.0 to ~1.414)
    /// - Returns: A string representation with 2 decimal places, clamped to display range
    public static func formatMagnitude(_ magnitude: Double) -> String {
        // Clamp to reasonable display range (0.0 to 1.0 for display purposes)
        let clampedMagnitude = max(0.0, min(1.0, magnitude))
        return String(format: "%.2f", clampedMagnitude)
    }
    
    /// Format a complete stick state for debug display
    /// Requirements: 8.1, 8.2, 8.3 - Display direction name, angle, and magnitude
    ///
    /// - Parameters:
    ///   - direction: The active direction name (or nil if no direction)
    ///   - angle: The current angle in degrees
    ///   - magnitude: The current magnitude
    /// - Returns: A formatted string describing the stick state
    public static func formatStickState(direction: String?, angle: Double, magnitude: Double) -> String {
        let directionStr = direction ?? "None"
        let angleStr = formatAngle(angle)
        let magnitudeStr = formatMagnitude(magnitude)
        return "\(directionStr) | \(angleStr) | \(magnitudeStr)"
    }
}
