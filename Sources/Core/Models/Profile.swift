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

/// A complete profile containing all mappings and settings
/// Requirements: 13.1, 13.6, 13.7 - Serializable to/from JSON
public struct Profile: Codable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var mappings: [Mapping]
    public var macros: [Macro]
    public var scripts: [Script]
    public var applicationBindings: [ApplicationBinding]?
    
    public init(
        id: UUID = UUID(),
        name: String,
        mappings: [Mapping] = [],
        macros: [Macro] = [],
        scripts: [Script] = [],
        applicationBindings: [ApplicationBinding]? = nil
    ) {
        self.id = id
        self.name = name
        self.mappings = mappings
        self.macros = macros
        self.scripts = scripts
        self.applicationBindings = applicationBindings
    }
}
