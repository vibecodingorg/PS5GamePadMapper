import SwiftUI
import PS5GamePadMapperCore
import AppKit

@main
struct PS5GamePadMapperApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .onAppear {
                    // Share the app state with the delegate for cleanup
                    appDelegate.appState = appState
                }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 900, height: 650)
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    /// Handle application lifecycle changes
    /// Requirements: 17.4 - Handle app termination with cleanup
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App became active - ensure coordinator is running
            appState.ensureCoordinatorRunning()
        case .inactive:
            // App became inactive - no action needed
            break
        case .background:
            // App went to background - cleanup if needed
            break
        @unknown default:
            break
        }
    }
}

/// Application delegate for handling app lifecycle events
/// Requirements: 17.4 - Handle app termination with cleanup
class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appState: AppState?
    
    /// Handle app launch with permission checks
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Permission checks are handled by AppState.checkPermissions()
        // which is called when ContentView appears
    }
    
    /// Handle app termination with cleanup
    /// Requirements: 17.4 - Handle app termination with cleanup
    func applicationWillTerminate(_ notification: Notification) {
        // Stop the coordinator to cleanup resources
        appState?.stopCoordinator()
    }
    
    /// Handle app becoming active
    func applicationDidBecomeActive(_ notification: Notification) {
        appState?.ensureCoordinatorRunning()
    }
    
    /// Prevent app from terminating while macros are running
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // If a macro is running, interrupt it first
        if let coordinator = appState?.coordinator, coordinator.isMacroRunning {
            coordinator.interruptMacro()
        }
        return .terminateNow
    }
}

/// Main content view that handles permission flow
/// Requirements: 16.1, 16.2
struct ContentView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.hasRequiredPermissions {
                MainWindowView(coordinator: appState.coordinator)
            } else {
                PermissionStatusView(viewModel: appState.permissionViewModel)
            }
        }
        .onAppear {
            appState.checkPermissions()
        }
    }
}

/// Application state managing permission flow and core coordinator
/// Requirements: 16.1, 16.2, 16.3, 17.4
@MainActor
class AppState: ObservableObject {
    @Published var hasRequiredPermissions: Bool = false
    
    let permissionViewModel: PermissionStatusViewModel
    let coordinator: AppCoordinator
    private let permissionManager: PermissionManager
    
    init() {
        // Initialize the central coordinator that wires all components
        self.coordinator = AppCoordinator()
        self.permissionManager = PermissionManager.shared
        self.permissionViewModel = PermissionStatusViewModel(permissionManager: permissionManager)
        
        // 先检查当前权限状态
        let currentStatus = permissionManager.checkAccessibilityPermission()
        self.hasRequiredPermissions = (currentStatus == .granted)
        
        // Set up continue callback
        permissionViewModel.onContinue = { [weak self] in
            guard let self = self else { return }
            self.hasRequiredPermissions = true
            self.startCoordinator()
        }
    }
    
    func checkPermissions() {
        updatePermissionState()
        
        // If permissions are already granted, start the coordinator
        if hasRequiredPermissions {
            startCoordinator()
        }
    }
    
    func ensureCoordinatorRunning() {
        if hasRequiredPermissions && !coordinator.isRunning {
            startCoordinator()
        }
    }
    
    private func updatePermissionState() {
        // Only require accessibility permission to proceed
        // Bluetooth is optional (USB controllers still work)
        let status = permissionManager.checkAccessibilityPermission()
        hasRequiredPermissions = (status == .granted)
    }
    
    /// Start the coordinator to begin processing inputs
    private func startCoordinator() {
        guard !coordinator.isRunning else { return }
        coordinator.start()
    }
    
    /// Stop the coordinator and cleanup
    /// Requirements: 17.4 - Handle app termination with cleanup
    func stopCoordinator() {
        coordinator.stop()
    }
    
    deinit {
        // Ensure cleanup on deallocation
        coordinator.stop()
    }
}
