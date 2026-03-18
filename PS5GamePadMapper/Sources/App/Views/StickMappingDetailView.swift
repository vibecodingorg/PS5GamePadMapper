import SwiftUI
import PS5GamePadMapperCore

/// Stick mapping detail view displaying in MappingDetailPanel
/// Requirements: 2.1, 2.2, 2.3, 2.4 - Display stick mapping configuration summary
struct StickMappingDetailView: View {
    let stick: StickType
    let directionMappings: [StickDirection: Mapping]
    let mouseConfig: MouseMoveAction?
    let onDirectionTapped: (StickDirection) -> Void
    let onEditTapped: () -> Void
    
    /// Explicitly stored stick mode from Profile (optional for backward compatibility)
    var stickMode: StickMappingMode?
    
    /// Computed property to determine current mode
    /// Priority: 1. Explicitly stored stickMode, 2. Inferred from config
    private var currentMode: StickMappingMode {
        // If stickMode is explicitly set, use it
        if let explicitMode = stickMode {
            NSLog("[StickMappingDetailView] currentMode: %@ (explicit), mouseConfig=%@, directionMappings.count=%d",
                  explicitMode.rawValue, mouseConfig != nil ? "YES" : "NO", directionMappings.count)
            return explicitMode
        }
        
        // Fallback: infer from configuration (for backward compatibility)
        let mode: StickMappingMode
        if mouseConfig != nil {
            mode = .mouse
        } else {
            mode = .direction // Default to direction mode
        }
        NSLog("[StickMappingDetailView] currentMode: %@ (inferred), mouseConfig=%@, directionMappings.count=%d",
              mode.rawValue, mouseConfig != nil ? "YES" : "NO", directionMappings.count)
        return mode
    }
    
    /// Count of configured directions
    var configuredDirectionCount: Int {
        directionMappings.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Current mode section
            currentModeSection
            
            Divider()
            
            // Mode-specific content based on currentMode
            switch currentMode {
            case .direction:
                if !directionMappings.isEmpty {
                    directionModeSummary
                } else {
                    noMappingPrompt
                }
            case .mouse:
                if mouseConfig != nil {
                    mouseModeSummary
                } else {
                    noMappingPrompt
                }
            }
            
            Spacer()
            
            // Edit button
            Button(action: onEditTapped) {
                Text("编辑映射")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Current Mode Section
    
    private var currentModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前模式")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Image(systemName: currentMode.icon)
                    .foregroundColor(currentMode.color)
                
                Text(currentMode.displayName)
                    .font(.body)
                
                if currentMode == .direction && !directionMappings.isEmpty {
                    Spacer()
                    Text("\(configuredDirectionCount)/8 方向")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Direction Mode Summary
    /// Requirements: 2.1, 2.4 - Display direction mapping summary with count and list
    private var directionModeSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("方向映射")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            DirectionMappingListView(
                directionMappings: directionMappings,
                onDirectionTapped: onDirectionTapped
            )
            .frame(maxHeight: 300)
        }
    }
    
    // MARK: - Mouse Mode Summary
    /// Requirements: 2.2 - Display mouse movement parameters
    private var mouseModeSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("鼠标移动参数")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let config = mouseConfig {
                VStack(alignment: .leading, spacing: 6) {
                    parameterRow(label: "灵敏度", value: String(format: "%.1f", config.sensitivity))
                    parameterRow(label: "死区", value: String(format: "%.2f", config.deadzone))
                    parameterRow(label: "曲线", value: config.curve.displayName)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }
    
    private func parameterRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.body)
    }
    
    // MARK: - No Mapping Prompt
    /// Requirements: 2.3 - Display prompt when no mapping is set
    private var noMappingPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.dashed")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("未配置映射")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("点击「编辑映射」来配置此摇杆")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Stick Mapping Mode Extensions

extension StickMappingMode {
    var displayName: String {
        switch self {
        case .direction: return "方向模式"
        case .mouse: return "鼠标模式"
        }
    }
    
    var icon: String {
        switch self {
        case .direction: return "arrow.up.left.and.arrow.down.right"
        case .mouse: return "cursorarrow.motionlines"
        }
    }
    
    var color: Color {
        switch self {
        case .direction: return .green
        case .mouse: return .purple
        }
    }
}

// MARK: - ResponseCurve Display Extension

extension ResponseCurve {
    var displayName: String {
        switch self {
        case .linear:
            return "线性"
        case .exponential(let power):
            return "指数 (\(String(format: "%.1f", power)))"
        }
    }
}

// MARK: - Direction Mapping Summary Helper

extension StickMappingDetailView {
    /// Returns a summary string of configured directions
    /// Requirements: 2.4 - Show count of configured directions
    static func directionSummary(from mappings: [StickDirection: Mapping]) -> String {
        return DirectionMappingSummary.summary(from: mappings)
    }
    
    /// Returns list of configured direction names
    /// Requirements: 2.4 - List the direction names
    static func configuredDirectionNames(from mappings: [StickDirection: Mapping]) -> [String] {
        return DirectionMappingSummary.configuredDirectionNames(from: mappings)
    }
}

#Preview {
    let sampleDirectionMappings: [StickDirection: Mapping] = [
        .up: Mapping(
            input: .direction(DirectionInput(stick: .left, direction: .up)),
            trigger: .press,
            action: .keyPress(KeyAction(keyCode: 13, modifiers: []))
        ),
        .down: Mapping(
            input: .direction(DirectionInput(stick: .left, direction: .down)),
            trigger: .press,
            action: .keyPress(KeyAction(keyCode: 1, modifiers: []))
        ),
        .left: Mapping(
            input: .direction(DirectionInput(stick: .left, direction: .left)),
            trigger: .press,
            action: .keyPress(KeyAction(keyCode: 0, modifiers: []))
        ),
        .right: Mapping(
            input: .direction(DirectionInput(stick: .left, direction: .right)),
            trigger: .press,
            action: .keyPress(KeyAction(keyCode: 2, modifiers: []))
        )
    ]
    
    return HStack(spacing: 20) {
        // Direction mode
        StickMappingDetailView(
            stick: .left,
            directionMappings: sampleDirectionMappings,
            mouseConfig: nil,
            onDirectionTapped: { _ in },
            onEditTapped: {}
        )
        .frame(width: 280)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        
        // Mouse mode
        StickMappingDetailView(
            stick: .right,
            directionMappings: [:],
            mouseConfig: MouseMoveAction(sensitivity: 2.0, deadzone: 0.15, curve: .linear),
            onDirectionTapped: { _ in },
            onEditTapped: {}
        )
        .frame(width: 280)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        
        // No mapping
        StickMappingDetailView(
            stick: .left,
            directionMappings: [:],
            mouseConfig: nil,
            onDirectionTapped: { _ in },
            onEditTapped: {}
        )
        .frame(width: 280)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    .padding()
}
