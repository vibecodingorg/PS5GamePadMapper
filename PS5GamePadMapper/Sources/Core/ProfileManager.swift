import Foundation
import os.log

/// Errors that can occur during profile management
public enum ProfileManagerError: Error, Equatable {
    case profileNotFound(name: String)
    case profileAlreadyExists(name: String)
    case invalidProfileData
    case fileSystemError(String)
    case profileNameEmpty
}

/// Validation result for stick mapping configuration
/// Requirements: 8.3 - Validate configuration on load and report errors
public struct StickMappingValidationResult {
    public let isValid: Bool
    public let errors: [String]
    public let validatedProfile: Profile
    
    public init(isValid: Bool, errors: [String], validatedProfile: Profile) {
        self.isValid = isValid
        self.errors = errors
        self.validatedProfile = validatedProfile
    }
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
    
    /// Logger for validation errors
    private let logger = Logger(subsystem: "com.ps5gamepadmapper", category: "ProfileManager")
    
    /// Callback when active profile changes (for mapping deactivation)
    public var onProfileWillChange: ((Profile?) -> Void)?
    
    /// Callback when active profile has changed
    public var onProfileDidChange: ((Profile?) -> Void)?
    
    /// Multiple handlers for profile changes (supports multiple subscribers)
    private var profileDidChangeHandlers: [String: (Profile?) -> Void] = [:]
    
    /// Add a handler for profile changes
    /// - Parameters:
    ///   - id: Unique identifier for the handler
    ///   - handler: Callback to invoke when profile changes
    public func addProfileDidChangeHandler(id: String, handler: @escaping (Profile?) -> Void) {
        profileDidChangeHandlers[id] = handler
    }
    
    /// Remove a handler for profile changes
    /// - Parameter id: Unique identifier of the handler to remove
    public func removeProfileDidChangeHandler(id: String) {
        profileDidChangeHandlers.removeValue(forKey: id)
    }
    
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
    /// Requirements: 8.3 - Validate configuration on load and report errors for invalid data
    public func loadProfile(_ name: String) throws -> Profile {
        let fileURL = profileURL(for: name)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ProfileManagerError.profileNotFound(name: name)
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let profile = try decoder.decode(Profile.self, from: data)
            
            // Validate stick mappings and return sanitized profile
            let validationResult = validateStickMappings(profile)
            if !validationResult.isValid {
                logger.warning("[ProfileManager] Profile '\(name)' has invalid stick mappings, using defaults for invalid values")
            }
            return validationResult.validatedProfile
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
        
        // Notify that profile has changed (legacy single callback)
        onProfileDidChange?(profile)
        
        // Notify all registered handlers
        for (_, handler) in profileDidChangeHandlers {
            handler(profile)
        }
    }
    
    // MARK: - Additional Methods
    
    /// Refresh the list of available profiles from disk
    /// Requirements: 13.5 - Display all available profiles with their names
    /// Requirements: 8.3 - Validate configuration on load and report errors for invalid data
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
                
                // Validate stick mappings and use sanitized profile
                let validationResult = validateStickMappings(profile)
                if !validationResult.isValid {
                    logger.warning("[ProfileManager] Profile '\(profile.name)' has invalid stick mappings, using defaults for invalid values")
                }
                profiles.append(validationResult.validatedProfile)
            } catch {
                // Skip invalid profile files
                logger.error("[ProfileManager] Failed to load profile from \(fileURL.lastPathComponent): \(error.localizedDescription)")
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
    
    // MARK: - Stick Mapping Validation
    // Requirements: 8.3 - Validate configuration on load and report errors for invalid data
    
    /// Validate and sanitize stick mapping configurations in a profile
    /// - Parameter profile: The profile to validate
    /// - Returns: Validation result with sanitized profile and any errors found
    public func validateStickMappings(_ profile: Profile) -> StickMappingValidationResult {
        var errors: [String] = []
        var validatedMappings: [Mapping] = []
        
        for mapping in profile.mappings {
            let (validatedMapping, mappingErrors) = validateMapping(mapping)
            validatedMappings.append(validatedMapping)
            errors.append(contentsOf: mappingErrors)
        }
        
        // Log errors if any
        for error in errors {
            logger.error("[ProfileManager] Stick mapping validation error: \(error)")
        }
        
        let validatedProfile = Profile(
            id: profile.id,
            name: profile.name,
            mappings: validatedMappings,
            macros: profile.macros,
            scripts: profile.scripts,
            applicationBindings: profile.applicationBindings
        )
        
        return StickMappingValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            validatedProfile: validatedProfile
        )
    }
    
    /// Validate a single mapping and return sanitized version with any errors
    private func validateMapping(_ mapping: Mapping) -> (Mapping, [String]) {
        var errors: [String] = []
        var validatedInput = mapping.input
        var validatedAction = mapping.action
        
        // Validate direction input threshold
        if case .direction(let directionInput) = mapping.input {
            let (validatedDirection, directionErrors) = validateDirectionInput(directionInput)
            validatedInput = .direction(validatedDirection)
            errors.append(contentsOf: directionErrors)
        }
        
        // Validate mouse move action parameters
        if case .mouseMove(let mouseAction) = mapping.action {
            let (validatedMouseAction, mouseErrors) = validateMouseMoveAction(mouseAction)
            validatedAction = .mouseMove(validatedMouseAction)
            errors.append(contentsOf: mouseErrors)
        }
        
        let validatedMapping = Mapping(
            id: mapping.id,
            input: validatedInput,
            trigger: mapping.trigger,
            action: validatedAction
        )
        
        return (validatedMapping, errors)
    }
    
    /// Validate direction input threshold and return sanitized version
    /// Requirements: 2.5 - Threshold values from 0.1 to 0.9
    private func validateDirectionInput(_ input: DirectionInput) -> (DirectionInput, [String]) {
        var errors: [String] = []
        var threshold = input.threshold
        
        // Threshold range: 0.1 to 0.9
        if threshold < 0.1 {
            errors.append("Direction threshold \(threshold) is below minimum 0.1 for \(input.stick.rawValue) \(input.direction.rawValue), using 0.1")
            threshold = 0.1
        } else if threshold > 0.9 {
            errors.append("Direction threshold \(threshold) is above maximum 0.9 for \(input.stick.rawValue) \(input.direction.rawValue), using 0.9")
            threshold = 0.9
        }
        
        let validatedInput = DirectionInput(
            stick: input.stick,
            direction: input.direction,
            threshold: threshold
        )
        
        return (validatedInput, errors)
    }
    
    /// Validate mouse move action parameters and return sanitized version
    /// Requirements: 4.1 - Sensitivity range 0.1 to 10.0
    /// Requirements: 4.2 - Deadzone range 0.0 to 0.5
    /// Requirements: 4.4 - Exponential power range 1.0 to 4.0
    private func validateMouseMoveAction(_ action: MouseMoveAction) -> (MouseMoveAction, [String]) {
        var errors: [String] = []
        var sensitivity = action.sensitivity
        var deadzone = action.deadzone
        var curve = action.curve
        
        // Sensitivity range: 0.1 to 10.0
        if sensitivity < 0.1 {
            errors.append("Mouse sensitivity \(sensitivity) is below minimum 0.1, using 0.1")
            sensitivity = 0.1
        } else if sensitivity > 10.0 {
            errors.append("Mouse sensitivity \(sensitivity) is above maximum 10.0, using 10.0")
            sensitivity = 10.0
        }
        
        // Deadzone range: 0.0 to 0.5
        if deadzone < 0.0 {
            errors.append("Mouse deadzone \(deadzone) is below minimum 0.0, using 0.0")
            deadzone = 0.0
        } else if deadzone > 0.5 {
            errors.append("Mouse deadzone \(deadzone) is above maximum 0.5, using 0.5")
            deadzone = 0.5
        }
        
        // Validate exponential power if applicable
        if case .exponential(let power) = action.curve {
            var validatedPower = power
            if power < 1.0 {
                errors.append("Exponential power \(power) is below minimum 1.0, using 1.0")
                validatedPower = 1.0
            } else if power > 4.0 {
                errors.append("Exponential power \(power) is above maximum 4.0, using 4.0")
                validatedPower = 4.0
            }
            curve = .exponential(power: validatedPower)
        }
        
        let validatedAction = MouseMoveAction(
            sensitivity: sensitivity,
            deadzone: deadzone,
            curve: curve
        )
        
        return (validatedAction, errors)
    }
    
    /// Load a profile with validation
    /// Requirements: 8.3 - Validate configuration on load and report errors for invalid data
    public func loadProfileWithValidation(_ name: String) throws -> StickMappingValidationResult {
        let profile = try loadProfile(name)
        return validateStickMappings(profile)
    }
}
