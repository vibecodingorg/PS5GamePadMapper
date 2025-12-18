import Foundation

/// A single input-to-action mapping
public struct Mapping: Codable, Equatable {
    public let input: InputSource
    public let trigger: TriggerMode
    public let action: Action
    
    public init(input: InputSource, trigger: TriggerMode, action: Action) {
        self.input = input
        self.trigger = trigger
        self.action = action
    }
}
