import Foundation

/// Protocol for the core mapping engine
/// Requirements: 4.1, 4.2, 4.5, 5.1, 5.2, 7.1, 7.2, 7.3
/// Requirements: 2.2, 4.4, 5.3, 5.4, 7.3 - Direction mapping support
public protocol MappingEngineProtocol {
    /// The currently active profile
    var activeProfile: Profile? { get set }
    
    /// Handle a button event and return resulting action results
    func handleButtonEvent(_ event: ButtonEvent) -> [ActionResult]
    
    /// Handle an axis event and return resulting actions
    func handleAxisEvent(_ event: AxisEvent) -> [Action]
    
    /// Handle a direction event and return resulting actions
    /// Requirements: 2.2, 5.2 - Direction mapping support
    func handleDirectionEvent(_ event: DirectionEvent) -> [Action]
}
