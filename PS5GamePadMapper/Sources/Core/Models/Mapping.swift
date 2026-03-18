import Foundation

/// A single input-to-action mapping
public struct Mapping: Codable, Equatable, Identifiable {
    public let id: UUID
    public let input: InputSource
    public let trigger: TriggerMode
    public let action: Action
    
    public init(id: UUID = UUID(), input: InputSource, trigger: TriggerMode, action: Action) {
        self.id = id
        self.input = input
        self.trigger = trigger
        self.action = action
    }
}
