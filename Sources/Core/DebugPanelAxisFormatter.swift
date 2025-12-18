import Foundation

/// Utility for formatting axis values in the debug panel
/// Requirements: 15.4 - Show normalized value with 2 decimal precision
public struct DebugPanelAxisFormatter {
    
    /// Format an axis value with exactly 2 decimal places
    /// Requirements: 15.4 - Show normalized value with 2 decimal precision
    ///
    /// - Parameter value: The normalized axis value to format
    /// - Returns: A string representation with exactly 2 decimal places (e.g., "0.50", "-1.00")
    public static func formatAxisValue(_ value: Double) -> String {
        return String(format: "%.2f", value)
    }
}
