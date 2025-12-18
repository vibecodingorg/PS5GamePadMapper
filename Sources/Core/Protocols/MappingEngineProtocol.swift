import Foundation

/// Protocol for the core mapping engine
/// Requirements: 4.1, 4.2, 4.5, 5.1, 5.2, 7.1, 7.2, 7.3
public protocol MappingEngineProtocol {
    /// The currently active profile
    var activeProfile: Profile? { get set }
    
    /// Handle a button event and return resulting actions
    func handleButtonEvent(_ event: ButtonEvent) -> [Action]
    
    /// Handle an axis event and return resulting actions
    func handleAxisEvent(_ event: AxisEvent) -> [Action]
}
