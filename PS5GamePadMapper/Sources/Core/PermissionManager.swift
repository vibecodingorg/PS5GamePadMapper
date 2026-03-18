import Foundation
import ApplicationServices
import CoreBluetooth

/// Permission Manager implementation for handling macOS system permissions
/// Requirements: 16.1, 16.2, 16.3
public final class PermissionManager: NSObject, PermissionManagerProtocol {
    
    // MARK: - Properties
    
    public private(set) var accessibilityStatus: PermissionStatus = .notDetermined
    public private(set) var bluetoothStatus: PermissionStatus = .notDetermined
    
    /// Callback when accessibility permission status changes
    public var onAccessibilityStatusChanged: ((PermissionStatus) -> Void)?
    
    /// Callback when Bluetooth permission status changes
    public var onBluetoothStatusChanged: ((PermissionStatus) -> Void)?
    
    private var centralManager: CBCentralManager?
    private var bluetoothCheckCompletion: ((PermissionStatus) -> Void)?
    
    // MARK: - Singleton
    
    public static let shared = PermissionManager()
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        // Check initial status
        accessibilityStatus = checkAccessibilityPermission()
        bluetoothStatus = checkBluetoothPermission()
    }
    
    // MARK: - Accessibility Permission
    
    /// Check if accessibility permission is granted
    /// Requirements: 16.1
    @discardableResult
    public func checkAccessibilityPermission() -> PermissionStatus {
        let trusted = AXIsProcessTrusted()
        let newStatus: PermissionStatus = trusted ? .granted : .notDetermined
        
        if newStatus != accessibilityStatus {
            accessibilityStatus = newStatus
            onAccessibilityStatusChanged?(newStatus)
        }
        
        return newStatus
    }
    
    /// Prompt user to grant accessibility permission
    /// Requirements: 16.1
    public func promptAccessibilityPermission() {
        // Create options dictionary to prompt the user
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        
        // This will show the system dialog if not already trusted
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        let newStatus: PermissionStatus = trusted ? .granted : .notDetermined
        if newStatus != accessibilityStatus {
            accessibilityStatus = newStatus
            onAccessibilityStatusChanged?(newStatus)
        }
    }
    
    /// Start monitoring accessibility permission changes
    public func startMonitoringAccessibility() {
        // Poll for accessibility status changes
        // macOS doesn't provide a notification for this, so we poll periodically
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAccessibilityPermission()
        }
    }
    
    // MARK: - Bluetooth Permission
    
    /// Check if Bluetooth permission is granted
    /// Requirements: 16.3
    @discardableResult
    public func checkBluetoothPermission() -> PermissionStatus {
        switch CBCentralManager.authorization {
        case .allowedAlways:
            bluetoothStatus = .granted
        case .denied:
            bluetoothStatus = .denied
        case .restricted:
            bluetoothStatus = .denied
        case .notDetermined:
            bluetoothStatus = .notDetermined
        @unknown default:
            bluetoothStatus = .notDetermined
        }
        
        return bluetoothStatus
    }
    
    /// Request Bluetooth permission
    /// Requirements: 16.3
    public func requestBluetoothPermission() {
        // Creating a CBCentralManager will trigger the permission prompt
        // if permission hasn't been determined yet
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }
    
    // MARK: - Limitation Messages
    
    /// Get a human-readable message explaining the limitation when permission is not granted
    /// Requirements: 16.2
    public func getLimitationMessage(for permission: PermissionType) -> String {
        switch permission {
        case .accessibility:
            return """
            Accessibility permission is required to emit keyboard and mouse events.
            
            Without this permission, PS5GamePadMapper cannot:
            • Send keyboard key presses
            • Control mouse movement and clicks
            • Execute macros and scripts
            
            To grant permission:
            1. Open System Settings
            2. Go to Privacy & Security → Accessibility
            3. Enable PS5GamePadMapper in the list
            """
            
        case .bluetooth:
            return """
            Bluetooth permission is required to connect to wireless controllers.
            
            Without this permission, PS5GamePadMapper cannot:
            • Detect Bluetooth-connected DualSense controllers
            • Read input from wireless controllers
            
            USB-connected controllers will still work without this permission.
            
            To grant permission:
            1. Open System Settings
            2. Go to Privacy & Security → Bluetooth
            3. Enable PS5GamePadMapper in the list
            """
        }
    }
    
    // MARK: - Utility Methods
    
    /// Check if all required permissions are granted
    public var hasAllRequiredPermissions: Bool {
        return accessibilityStatus == .granted
    }
    
    /// Check if the app can emit events (requires accessibility permission)
    public var canEmitEvents: Bool {
        return accessibilityStatus == .granted
    }
    
    /// Check if the app can use Bluetooth (requires Bluetooth permission)
    public var canUseBluetooth: Bool {
        return bluetoothStatus == .granted
    }
    
    /// Ensure Bluetooth permission is requested before Bluetooth operations
    /// Requirements: 16.3
    /// - Returns: true if Bluetooth permission is granted, false otherwise
    @discardableResult
    public func ensureBluetoothPermission() -> Bool {
        let status = checkBluetoothPermission()
        
        if status == .notDetermined {
            // Request permission if not yet determined
            requestBluetoothPermission()
            return false
        }
        
        return status == .granted
    }
}

// MARK: - CBCentralManagerDelegate

extension PermissionManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Update Bluetooth status based on central manager state
        let newStatus = checkBluetoothPermission()
        
        if newStatus != bluetoothStatus {
            bluetoothStatus = newStatus
            onBluetoothStatusChanged?(newStatus)
        }
    }
}
