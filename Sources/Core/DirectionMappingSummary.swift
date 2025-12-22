import Foundation

/// Helper for generating direction mapping summaries
/// Requirements: 2.1, 2.4 - Display direction mapping summary with count and list
public struct DirectionMappingSummary {
    
    /// Returns a summary string of configured directions
    /// Requirements: 2.4 - Show count of configured directions
    /// - Parameter mappings: Dictionary of direction to mapping
    /// - Returns: Summary string like "4/8 方向" or "未配置"
    public static func summary(from mappings: [StickDirection: Mapping]) -> String {
        let count = mappings.count
        if count == 0 {
            return "未配置"
        }
        return "\(count)/8 方向"
    }
    
    /// Returns list of configured direction names sorted by angle
    /// Requirements: 2.4 - List the direction names
    /// - Parameter mappings: Dictionary of direction to mapping
    /// - Returns: Array of localized direction names sorted by center angle
    public static func configuredDirectionNames(from mappings: [StickDirection: Mapping]) -> [String] {
        return mappings.keys.sorted { $0.centerAngle < $1.centerAngle }.map { $0.localizedName }
    }
    
    /// Returns the count of configured directions
    /// - Parameter mappings: Dictionary of direction to mapping
    /// - Returns: Number of configured directions (0-8)
    public static func configuredCount(from mappings: [StickDirection: Mapping]) -> Int {
        return mappings.count
    }
}
