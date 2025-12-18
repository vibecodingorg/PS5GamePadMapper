import Foundation

/// Protocol for processing raw input data
/// Requirements: 3.2, 3.4, 6.2, 6.3, 6.4
public protocol InputProcessorProtocol {
    /// Process a raw button input into a button event
    func processButtonInput(_ input: RawButtonInput) -> ButtonEvent
    
    /// Process a raw axis input into an axis event with normalization and deadzone
    func processAxisInput(_ input: RawAxisInput, config: AxisConfig) -> AxisEvent
}
