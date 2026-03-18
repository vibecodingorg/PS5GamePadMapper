import Foundation

/// Represents a connected DualSense controller
/// Requirements: 1.1, 1.2, 1.3, 1.4
public struct Controller: Equatable, Identifiable {
    public let id: String
    public let deviceId: String
    public let name: String
    public let connectionType: ConnectionType
    public let batteryLevel: Int?
    
    public init(
        deviceId: String,
        name: String,
        connectionType: ConnectionType,
        batteryLevel: Int? = nil
    ) {
        self.id = deviceId
        self.deviceId = deviceId
        self.name = name
        self.connectionType = connectionType
        self.batteryLevel = batteryLevel
    }
}
