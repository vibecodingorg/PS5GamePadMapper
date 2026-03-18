import Foundation

/// Controller connection type
/// Requirements: 1.3 - Display connection type (USB or Bluetooth)
public enum ConnectionType: String, Codable, Equatable {
    case usb = "USB"
    case bluetooth = "Bluetooth"
}
