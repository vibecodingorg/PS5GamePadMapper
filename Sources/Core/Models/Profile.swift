import Foundation

/// Application binding for automatic profile switching
/// Requirements: 14.2 - Support selecting applications by bundle identifier
public struct ApplicationBinding: Codable, Equatable {
    public let bundleIdentifier: String
    public let profileId: UUID
    
    public init(bundleIdentifier: String, profileId: UUID) {
        self.bundleIdentifier = bundleIdentifier
        self.profileId = profileId
    }
}

/// Stick mapping mode enum - stored explicitly in Profile
/// Requirements: 3.1 - Direction mode and mouse mode
public enum StickMappingMode: String, Codable, Equatable {
    case direction = "direction"
    case mouse = "mouse"
}

/// A complete profile containing all mappings and settings
/// Requirements: 13.1, 13.6, 13.7 - Serializable to/from JSON
public struct Profile: Codable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var mappings: [Mapping]
    public var macros: [Macro]
    public var scripts: [Script]
    public var applicationBindings: [ApplicationBinding]?
    
    /// Explicitly stored stick mapping modes for each stick
    /// This ensures mode is preserved even when no mappings are configured
    public var stickModes: [StickType: StickMappingMode]?
    
    public init(
        id: UUID = UUID(),
        name: String,
        mappings: [Mapping] = [],
        macros: [Macro] = [],
        scripts: [Script] = [],
        applicationBindings: [ApplicationBinding]? = nil,
        stickModes: [StickType: StickMappingMode]? = nil
    ) {
        self.id = id
        self.name = name
        self.mappings = mappings
        self.macros = macros
        self.scripts = scripts
        self.applicationBindings = applicationBindings
        self.stickModes = stickModes
    }
    
    /// Get the mode for a specific stick, defaulting to direction mode
    public func stickMode(for stick: StickType) -> StickMappingMode {
        return stickModes?[stick] ?? .direction
    }
    
    /// Create a copy with updated stick mode
    public func withStickMode(_ mode: StickMappingMode, for stick: StickType) -> Profile {
        var newProfile = self
        if newProfile.stickModes == nil {
            newProfile.stickModes = [:]
        }
        newProfile.stickModes?[stick] = mode
        return newProfile
    }
}
