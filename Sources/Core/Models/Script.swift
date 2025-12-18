import Foundation

/// A script definition for complex input logic
/// Requirements: 12.1 - Execute scripts in dedicated execution context
public struct Script: Codable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let source: String
    
    public init(id: UUID = UUID(), name: String, source: String) {
        self.id = id
        self.name = name
        self.source = source
    }
}
