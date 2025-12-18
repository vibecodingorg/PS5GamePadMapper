import SwiftUI
import PS5GamePadMapperCore

/// View for displaying permission status and prompting users to grant permissions
/// Requirements: 16.1, 16.2, 16.3
struct PermissionStatusView: View {
    @ObservedObject var viewModel: PermissionStatusViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Permissions Required")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("PS5GamePadMapper needs certain permissions to function properly.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 10)
            
            // Permission cards
            VStack(spacing: 16) {
                PermissionCard(
                    title: "Accessibility",
                    description: "Required to emit keyboard and mouse events",
                    status: viewModel.accessibilityStatus,
                    isRequired: true,
                    onRequestPermission: viewModel.requestAccessibilityPermission
                )
                
                PermissionCard(
                    title: "Bluetooth",
                    description: "Required for wireless controller support",
                    status: viewModel.bluetoothStatus,
                    isRequired: false,
                    onRequestPermission: viewModel.requestBluetoothPermission
                )
            }
            
            // Limitation message if accessibility not granted
            if viewModel.accessibilityStatus != .granted {
                LimitationMessageView(
                    message: viewModel.accessibilityLimitationMessage
                )
            }
            
            Spacer()
            
            // Continue button (only if accessibility is granted)
            if viewModel.accessibilityStatus == .granted {
                Button("Continue") {
                    viewModel.onContinue?()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(30)
        .frame(minWidth: 500, minHeight: 450)
        .onAppear {
            viewModel.startMonitoring()
        }
    }
}

/// Individual permission card view
struct PermissionCard: View {
    let title: String
    let description: String
    let status: PermissionStatus
    let isRequired: Bool
    let onRequestPermission: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Status icon
            statusIcon
                .frame(width: 40, height: 40)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                    
                    if isRequired {
                        Text("Required")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    } else {
                        Text("Optional")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action button
            if status != .granted {
                Button("Grant") {
                    onRequestPermission()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundColor(.green)
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .font(.title)
                .foregroundColor(.red)
        case .notDetermined:
            Image(systemName: "questionmark.circle.fill")
                .font(.title)
                .foregroundColor(.orange)
        }
    }
    
    private var cardBackground: Color {
        switch status {
        case .granted:
            return Color.green.opacity(0.05)
        case .denied:
            return Color.red.opacity(0.05)
        case .notDetermined:
            return Color.orange.opacity(0.05)
        }
    }
    
    private var borderColor: Color {
        switch status {
        case .granted:
            return Color.green.opacity(0.3)
        case .denied:
            return Color.red.opacity(0.3)
        case .notDetermined:
            return Color.orange.opacity(0.3)
        }
    }
}

/// View for displaying limitation message
struct LimitationMessageView: View {
    let message: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Limited Functionality")
                    .font(.headline)
            }
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

/// View model for permission status
@MainActor
class PermissionStatusViewModel: ObservableObject {
    @Published var accessibilityStatus: PermissionStatus = .notDetermined
    @Published var bluetoothStatus: PermissionStatus = .notDetermined
    
    var onContinue: (() -> Void)?
    
    private let permissionManager: PermissionManager
    
    var accessibilityLimitationMessage: String {
        permissionManager.getLimitationMessage(for: .accessibility)
    }
    
    var bluetoothLimitationMessage: String {
        permissionManager.getLimitationMessage(for: .bluetooth)
    }
    
    init(permissionManager: PermissionManager = .shared) {
        self.permissionManager = permissionManager
        updateStatus()
    }
    
    func startMonitoring() {
        permissionManager.onAccessibilityStatusChanged = { [weak self] status in
            Task { @MainActor in
                self?.accessibilityStatus = status
            }
        }
        
        permissionManager.onBluetoothStatusChanged = { [weak self] status in
            Task { @MainActor in
                self?.bluetoothStatus = status
            }
        }
        
        permissionManager.startMonitoringAccessibility()
        updateStatus()
    }
    
    func requestAccessibilityPermission() {
        permissionManager.promptAccessibilityPermission()
        updateStatus()
    }
    
    func requestBluetoothPermission() {
        permissionManager.requestBluetoothPermission()
        updateStatus()
    }
    
    private func updateStatus() {
        accessibilityStatus = permissionManager.checkAccessibilityPermission()
        bluetoothStatus = permissionManager.checkBluetoothPermission()
    }
}

#Preview {
    PermissionStatusView(viewModel: PermissionStatusViewModel())
}
