import SwiftUI
import PS5GamePadMapperCore

/// Displays controller connection status including name, connection type, and battery level
/// Requirements: 18.1 - Display connected controller status
struct ControllerStatusView: View {
    let controller: Controller?
    
    var body: some View {
        HStack(spacing: 12) {
            // Connection indicator
            Circle()
                .fill(controller != nil ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
            
            if let controller = controller {
                // Controller name
                Text(controller.name)
                    .font(.headline)
                
                // Connection type badge
                ConnectionTypeBadge(connectionType: controller.connectionType)
                
                // Battery indicator
                if let batteryLevel = controller.batteryLevel {
                    BatteryIndicator(level: batteryLevel)
                }
            } else {
                Text("未连接控制器")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

/// Badge showing USB or Bluetooth connection type
struct ConnectionTypeBadge: View {
    let connectionType: ConnectionType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: connectionType == .usb ? "cable.connector" : "antenna.radiowaves.left.and.right")
                .font(.caption)
            Text(connectionType == .usb ? "USB" : "Bluetooth")
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.2))
        .foregroundColor(.blue)
        .cornerRadius(4)
    }
}

/// Battery level indicator with icon and percentage
struct BatteryIndicator: View {
    let level: Int
    
    private var batteryIcon: String {
        switch level {
        case 0..<20: return "battery.0"
        case 20..<40: return "battery.25"
        case 40..<60: return "battery.50"
        case 60..<80: return "battery.75"
        default: return "battery.100"
        }
    }
    
    private var batteryColor: Color {
        switch level {
        case 0..<20: return .red
        case 20..<40: return .orange
        default: return .green
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: batteryIcon)
                .foregroundColor(batteryColor)
            Text("\(level)%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ControllerStatusView(controller: Controller(
            deviceId: "test-1",
            name: "DualSense Wireless Controller",
            connectionType: .usb,
            batteryLevel: 75
        ))
        
        ControllerStatusView(controller: Controller(
            deviceId: "test-2",
            name: "DualSense Wireless Controller",
            connectionType: .bluetooth,
            batteryLevel: 25
        ))
        
        ControllerStatusView(controller: nil)
    }
    .padding()
}
