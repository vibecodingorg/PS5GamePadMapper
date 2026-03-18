import Foundation

/// Permission status enumeration
public enum PermissionStatus: Equatable {
    case granted
    case denied
    case notDetermined
}

/// Protocol for managing system permissions
/// Requirements: 16.1, 16.2, 16.3
public protocol PermissionManagerProtocol {
    /// Current accessibility permission status
    var accessibilityStatus: PermissionStatus { get }
    
    /// Current Bluetooth permission status
    var bluetoothStatus: PermissionStatus { get }
    
    /// Check if accessibility permission is granted
    func checkAccessibilityPermission() -> PermissionStatus
    
    /// Prompt user to grant accessibility permission
    func promptAccessibilityPermission()
    
    /// Check if Bluetooth permission is granted
    func checkBluetoothPermission() -> PermissionStatus
    
    /// Request Bluetooth permission
    func requestBluetoothPermission()
    
    /// Get a human-readable message explaining the limitation when permission is not granted
    func getLimitationMessage(for permission: PermissionType) -> String
}

/// Types of permissions the app requires
public enum PermissionType {
    case accessibility
    case bluetooth
}
