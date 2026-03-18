import Foundation

/// Protocol for profile management
/// Requirements: 13.1, 13.2, 13.3, 13.4, 13.5
public protocol ProfileManagerProtocol {
    /// All available profiles
    var profiles: [Profile] { get }
    
    /// The currently active profile
    var activeProfile: Profile? { get }
    
    /// Load a profile by name
    func loadProfile(_ name: String) throws -> Profile
    
    /// Save a profile to storage
    func saveProfile(_ profile: Profile) throws
    
    /// Delete a profile by name
    func deleteProfile(_ name: String) throws
    
    /// Clone a profile with a new name
    func cloneProfile(_ profile: Profile, newName: String) throws -> Profile
    
    /// Set the active profile
    func setActiveProfile(_ profile: Profile)
}
