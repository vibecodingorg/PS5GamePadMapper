import Foundation

/// Errors that can occur during profile management
public enum ProfileManagerError: Error, Equatable {
    case profileNotFound(name: String)
    case profileAlreadyExists(name: String)
    case invalidProfileData
    case fileSystemError(String)
    case profileNameEmpty
}

/// Profile manager for loading, saving, and managing profiles
/// Requirements: 13.1, 13.2, 13.3, 13.4, 13.5
public final class ProfileManager: ProfileManagerProtocol {
    
    // MARK: - Properties
    
    /// All available profiles
    public private(set) var profiles: [Profile] = []
    
    /// The currently active profile
    public private(set) var activeProfile: Profile?
    
    /// Directory where profiles are stored
    private let profilesDirectory: URL
    
    /// JSON encoder for serialization
    private let encoder: JSONEncoder
    
    /// JSON decoder for deserialization
    private let decoder: JSONDecoder
    
    /// Callback when active profile changes (for mapping deactivation)
    public var onProfileWillChange: ((Profile?) -> Void)?
    
    /// Callback when active profile has changed
    public var onProfileDidChange: ((Profile?) -> Void)?
    
    // MARK: - Initialization
    
    /// Initialize with a custom profiles directory
    public init(profilesDirectory: URL) {
        self.profilesDirectory = profilesDirectory
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        
        // Create profiles directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: profilesDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    
    /// Initialize with the default profiles directory in Application Support
    public convenience init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let profilesDir = appSupport
            .appendingPathComponent("PS5GamePadMapper", isDirectory: true)
            .appendingPathComponent("Profiles", isDirectory: true)
        self.init(profilesDirectory: profilesDir)
    }
    
    // MARK: - ProfileManagerProtocol
    
    /// Load a profile by name
    /// Requirements: 13.2 - Parse JSON file and apply all mappings within 500ms
    public func loadProfile(_ name: String) throws -> Profile {
        let fileURL = profileURL(for: name)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ProfileManagerError.profileNotFound(name: name)
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let profile = try decoder.decode(Profile.self, from: data)
            return profile
        } catch is DecodingError {
            throw ProfileManagerError.invalidProfileData
        } catch {
            throw ProfileManagerError.fileSystemError(error.localizedDescription)
        }
    }
    
    /// Save a profile to storage
    /// Requirements: 13.1 - Write configuration to local JSON file
    public func saveProfile(_ profile: Profile) throws {
        print("[ProfileManager] saveProfile called - name: \(profile.name), macros: \(profile.macros.count), scripts: \(profile.scripts.count)")
        
        guard !profile.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ProfileManagerError.profileNameEmpty
        }
        
        let fileURL = profileURL(for: profile.name)
        print("[ProfileManager] Saving to: \(fileURL.path)")
        
        do {
            let data = try encoder.encode(profile)
            try data.write(to: fileURL, options: .atomic)
            print("[ProfileManager] File written successfully, size: \(data.count) bytes")
            
            // Update profiles list
            if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[index] = profile
                print("[ProfileManager] Updated profiles array at index \(index)")
            } else {
                profiles.append(profile)
                print("[ProfileManager] Appended new profile to array")
            }
            
            // Update active profile if it's the same one
            if activeProfile?.id == profile.id {
                activeProfile = profile
                print("[ProfileManager] Updated activeProfile")
            }
            
            print("[ProfileManager] After save - profiles count: \(profiles.count), activeProfile macros: \(activeProfile?.macros.count ?? 0)")
        } catch is EncodingError {
            throw ProfileManagerError.invalidProfileData
        } catch {
            throw ProfileManagerError.fileSystemError(error.localizedDescription)
        }
    }
    
    /// Delete a profile by name
    public func deleteProfile(_ name: String) throws {
        let fileURL = profileURL(for: name)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ProfileManagerError.profileNotFound(name: name)
        }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            profiles.removeAll { $0.name == name }
            
            // Clear active profile if it was deleted
            if activeProfile?.name == name {
                activeProfile = nil
            }
        } catch {
            throw ProfileManagerError.fileSystemError(error.localizedDescription)
        }
    }

    
    /// Clone a profile with a new name
    /// Requirements: 13.4 - Create new profile with identical mappings and unique name
    public func cloneProfile(_ profile: Profile, newName: String) throws -> Profile {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ProfileManagerError.profileNameEmpty
        }
        
        // Check if a profile with the new name already exists
        let fileURL = profileURL(for: newName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            throw ProfileManagerError.profileAlreadyExists(name: newName)
        }
        
        // Create a new profile with:
        // - New UUID (different from original)
        // - New name (different from original)
        // - Identical mappings, macros, scripts, and application bindings
        let clonedProfile = Profile(
            id: UUID(),  // New unique ID
            name: newName,  // New unique name
            mappings: profile.mappings,  // Identical mappings
            macros: profile.macros,  // Identical macros
            scripts: profile.scripts,  // Identical scripts
            applicationBindings: profile.applicationBindings  // Identical bindings
        )
        
        // Save the cloned profile
        try saveProfile(clonedProfile)
        
        return clonedProfile
    }
    
    /// Set the active profile
    /// Requirements: 13.3 - Deactivate all current mappings before activating new ones
    public func setActiveProfile(_ profile: Profile) {
        // Notify that profile will change (allows deactivation of current mappings)
        onProfileWillChange?(activeProfile)
        
        // Set the new active profile
        activeProfile = profile
        
        // Notify that profile has changed
        onProfileDidChange?(profile)
    }
    
    // MARK: - Additional Methods
    
    /// Refresh the list of available profiles from disk
    /// Requirements: 13.5 - Display all available profiles with their names
    public func refreshProfiles() throws {
        profiles.removeAll()
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: profilesDirectory.path) else {
            return
        }
        
        let contents = try fileManager.contentsOfDirectory(
            at: profilesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        
        for fileURL in contents where fileURL.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: fileURL)
                let profile = try decoder.decode(Profile.self, from: data)
                profiles.append(profile)
            } catch {
                // Skip invalid profile files
                continue
            }
        }
        
        // Sort profiles by name for consistent ordering
        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Get a profile by ID
    public func profile(withId id: UUID) -> Profile? {
        return profiles.first { $0.id == id }
    }
    
    /// Get a profile by name
    public func profile(named name: String) -> Profile? {
        return profiles.first { $0.name == name }
    }
    
    /// Check if a profile with the given name exists
    public func profileExists(named name: String) -> Bool {
        let fileURL = profileURL(for: name)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Deactivate the current profile
    public func deactivateProfile() {
        onProfileWillChange?(activeProfile)
        activeProfile = nil
        onProfileDidChange?(nil)
    }
    
    // MARK: - Private Methods
    
    /// Get the file URL for a profile with the given name
    private func profileURL(for name: String) -> URL {
        let sanitizedName = name.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return profilesDirectory.appendingPathComponent("\(sanitizedName).json")
    }
}
