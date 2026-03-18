import Foundation

/// Protocol for controller device management
/// Requirements: 1.1, 1.2, 1.5, 1.6
public protocol ControllerManagerProtocol: AnyObject {
    /// Currently connected controllers
    var connectedControllers: [Controller] { get }
    
    /// Callback when a controller connects
    var onControllerConnected: ((Controller) -> Void)? { get set }
    
    /// Callback when a controller disconnects
    var onControllerDisconnected: ((Controller) -> Void)? { get set }
    
    /// Start discovering controllers
    func startDiscovery()
    
    /// Stop discovering controllers
    func stopDiscovery()
}
