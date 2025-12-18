import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property-based tests for Profile cloning
/// **Feature: ps5-gamepad-mapper, Property 16: Profile Clone Identity**
final class ProfileCloneIdentityPropertyTests: XCTestCase {
    
    private var profileManager: ProfileManager!
    private var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Create a temporary directory for test profiles
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        profileManager = ProfileManager(profilesDirectory: tempDirectory)
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        profileManager = nil
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - Property 16: Profile Clone Identity
    
    /// **Feature: ps5-gamepad-mapper, Property 16: Profile Clone Identity**
    /// **Validates: Requirements 13.4**
    ///
    /// *For any* profile clone operation, the cloned profile SHALL have:
    /// - Identical mappings to the original
    /// - Identical macros to the original
    /// - A different name from the original
    /// - A different UUID from the original
    func testProfileCloneIdentity() {
        property("Profile clone has identical content but different identity") <- forAll { (profile: Profile) in
            // Create a fresh profile manager for each test to avoid conflicts
            let testDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try? FileManager.default.createDirectory(
                at: testDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            defer {
                try? FileManager.default.removeItem(at: testDir)
            }
            
            let manager = ProfileManager(profilesDirectory: testDir)
            
            // Generate a unique new name that's different from the original
            let newName = "\(profile.name)_clone_\(UUID().uuidString.prefix(8))"
            
            do {
                // Clone the profile
                let clonedProfile = try manager.cloneProfile(profile, newName: newName)
                
                // Property 16 requirements:
                // 1. Identical mappings to the original
                let mappingsIdentical = clonedProfile.mappings == profile.mappings
                
                // 2. Identical macros to the original
                let macrosIdentical = clonedProfile.macros == profile.macros
                
                // 3. Identical scripts to the original
                let scriptsIdentical = clonedProfile.scripts == profile.scripts
                
                // 4. Identical application bindings to the original
                let bindingsIdentical = clonedProfile.applicationBindings == profile.applicationBindings
                
                // 5. A different name from the original
                let nameIsDifferent = clonedProfile.name != profile.name
                
                // 6. A different UUID from the original
                let idIsDifferent = clonedProfile.id != profile.id
                
                // 7. The new name matches what we requested
                let nameMatchesRequest = clonedProfile.name == newName
                
                return mappingsIdentical
                    && macrosIdentical
                    && scriptsIdentical
                    && bindingsIdentical
                    && nameIsDifferent
                    && idIsDifferent
                    && nameMatchesRequest
            } catch {
                // Clone operation should not fail for valid profiles
                return false
            }
        }
    }
    
    /// Additional property: Cloned profile can be loaded back from disk
    func testClonedProfilePersistence() {
        property("Cloned profile is persisted and can be loaded") <- forAll { (profile: Profile) in
            let testDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try? FileManager.default.createDirectory(
                at: testDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            defer {
                try? FileManager.default.removeItem(at: testDir)
            }
            
            let manager = ProfileManager(profilesDirectory: testDir)
            let newName = "clone_\(UUID().uuidString.prefix(8))"
            
            do {
                // Clone the profile
                let clonedProfile = try manager.cloneProfile(profile, newName: newName)
                
                // Load it back from disk
                let loadedProfile = try manager.loadProfile(newName)
                
                // Verify the loaded profile matches the cloned profile
                return loadedProfile.id == clonedProfile.id
                    && loadedProfile.name == clonedProfile.name
                    && loadedProfile.mappings == clonedProfile.mappings
                    && loadedProfile.macros == clonedProfile.macros
                    && loadedProfile.scripts == clonedProfile.scripts
            } catch {
                return false
            }
        }
    }
}
