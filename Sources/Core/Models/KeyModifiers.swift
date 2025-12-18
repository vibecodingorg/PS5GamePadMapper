import Foundation

/// Keyboard modifier keys as an OptionSet
/// Requirements: 4.3 - Support modifier key combinations (Cmd, Ctrl, Alt, Shift)
public struct KeyModifiers: OptionSet, Codable, Equatable, Hashable {
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let command = KeyModifiers(rawValue: 1 << 0)
    public static let control = KeyModifiers(rawValue: 1 << 1)
    public static let option = KeyModifiers(rawValue: 1 << 2)
    public static let shift = KeyModifiers(rawValue: 1 << 3)
    
    /// Returns all active modifiers in the order they should be emitted
    /// Requirements: 4.4 - Emit all modifier keys before the primary key
    public var orderedModifiers: [KeyModifiers] {
        var result: [KeyModifiers] = []
        if contains(.command) { result.append(.command) }
        if contains(.control) { result.append(.control) }
        if contains(.option) { result.append(.option) }
        if contains(.shift) { result.append(.shift) }
        return result
    }
}
