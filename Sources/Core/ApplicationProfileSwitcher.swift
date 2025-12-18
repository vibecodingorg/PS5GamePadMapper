import Foundation
import AppKit

/// Monitors foreground application changes and switches profiles automatically
/// Requirements: 14.1, 14.2, 14.3
public final class ApplicationProfileSwitcher {
    
    // MARK: - Properties
    
    /// The profile manager to use for switching profiles
    private weak var profileManager: ProfileManager?
    
    /// Application bindings mapping bundle identifiers to profile IDs
    private var applicationBindings: [String: UUID] = [:]
    
    /// Whether application-based switching is enabled
    public private(set) var isEnabled: Bool = false
    
    /// The profile that was active before automatic switching (for restoration)
    private var previousProfileId: UUID?
    
    /// Observer for workspace notifications
    private var workspaceObserver: NSObjectProtocol?
    
    /// Callback when profile is automatically switched
    public var onProfileSwitched: ((Profile, String) -> Void)?
    
    // MARK: - Initialization
    
    public init(profileManager: ProfileManager) {
        self.profileManager = profileManager
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring foreground application changes
    /// Requirements: 14.1 - Switch to associated profile within 1 second
    public func startMonitoring() {
        guard !isEnabled else { return }
        
        isEnabled = true
        
        // Observe application activation notifications
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleApplicationActivation(notification)
        }
        
        // Check current foreground application
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            handleApplicationChange(bundleIdentifier: frontApp.bundleIdentifier)
        }
    }
    
    /// Stop monitoring foreground application changes
    public func stopMonitoring() {
        guard isEnabled else { return }
        
        isEnabled = false
        
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
    }

    
    /// Add an application binding
    /// Requirements: 14.2 - Support selecting applications by bundle identifier
    public func addBinding(bundleIdentifier: String, profileId: UUID) {
        applicationBindings[bundleIdentifier] = profileId
    }
    
    /// Remove an application binding
    public func removeBinding(bundleIdentifier: String) {
        applicationBindings.removeValue(forKey: bundleIdentifier)
    }
    
    /// Get the profile ID bound to a bundle identifier
    public func profileId(for bundleIdentifier: String) -> UUID? {
        return applicationBindings[bundleIdentifier]
    }
    
    /// Get all application bindings
    public func getAllBindings() -> [String: UUID] {
        return applicationBindings
    }
    
    /// Clear all application bindings
    public func clearAllBindings() {
        applicationBindings.removeAll()
    }
    
    /// Load bindings from a profile's application bindings
    public func loadBindings(from profile: Profile) {
        guard let bindings = profile.applicationBindings else { return }
        
        for binding in bindings {
            applicationBindings[binding.bundleIdentifier] = binding.profileId
        }
    }
    
    /// Load bindings from all profiles
    public func loadBindingsFromAllProfiles() {
        guard let manager = profileManager else { return }
        
        applicationBindings.removeAll()
        
        for profile in manager.profiles {
            if let bindings = profile.applicationBindings {
                for binding in bindings {
                    applicationBindings[binding.bundleIdentifier] = binding.profileId
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Handle application activation notification
    private func handleApplicationActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        handleApplicationChange(bundleIdentifier: app.bundleIdentifier)
    }
    
    /// Handle application change
    /// Requirements: 14.1 - Switch to associated profile within 1 second
    /// Requirements: 14.3 - Maintain current profile when no association matches
    private func handleApplicationChange(bundleIdentifier: String?) {
        guard let bundleId = bundleIdentifier,
              let manager = profileManager else {
            return
        }
        
        // Check if there's a binding for this application
        if let targetProfileId = applicationBindings[bundleId] {
            // Found a binding - switch to the associated profile
            if let targetProfile = manager.profile(withId: targetProfileId) {
                // Save current profile for potential restoration
                if previousProfileId == nil {
                    previousProfileId = manager.activeProfile?.id
                }
                
                // Only switch if not already on this profile
                if manager.activeProfile?.id != targetProfileId {
                    manager.setActiveProfile(targetProfile)
                    onProfileSwitched?(targetProfile, bundleId)
                }
            }
        }
        // Requirements: 14.3 - When no association matches, maintain current profile
        // (No action needed - we simply don't switch)
    }
    
    /// Restore the previous profile (before automatic switching)
    public func restorePreviousProfile() {
        guard let manager = profileManager,
              let previousId = previousProfileId,
              let previousProfile = manager.profile(withId: previousId) else {
            return
        }
        
        manager.setActiveProfile(previousProfile)
        previousProfileId = nil
    }
}
