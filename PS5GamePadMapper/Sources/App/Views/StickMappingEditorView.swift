import SwiftUI
import PS5GamePadMapperCore

/// Stick mapping editor view for configuring direction and mouse modes
/// Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6
struct StickMappingEditorView: View {
    let stick: StickType
    let currentX: Double
    let currentY: Double
    let directionMappings: [StickDirection: Mapping]
    let mouseConfig: MouseMoveAction?
    let availableMacros: [Macro]
    let availableScripts: [Script]
    let onDirectionMappingChanged: (StickDirection, Mapping?) -> Void
    let onMouseConfigChanged: (MouseMoveAction?) -> Void
    let onDismiss: () -> Void
    
    /// Explicitly stored stick mode from Profile
    var stickMode: StickMappingMode?
    
    /// Callback when stick mode changes
    var onStickModeChanged: ((StickMappingMode) -> Void)?
    
    /// Preselected direction when opening from direction list
    var preselectedDirection: StickDirection?
    
    /// Selected mode state
    /// Requirements: 3.1, 5.1 - Display mode selector with Direction and Mouse options
    @State private var selectedMode: StickMappingMode = .direction
    
    /// Mouse mode parameters
    /// Requirements: 4.1, 4.2, 4.3, 4.4 - Mouse mode configuration parameters
    @State private var sensitivity: Double = 1.0
    @State private var deadzone: Double = 0.1
    @State private var responseCurve: ResponseCurveOption = .linear
    @State private var exponentialPower: Double = 2.0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Mode selector
            /// Requirements: 3.1, 5.1 - Mode selector with Direction and Mouse options
            modeSelector
                .padding()
            
            Divider()
            
            // Mode-specific content
            /// Requirements: 3.2, 3.3, 5.2, 5.3, 5.4 - Mode-specific configuration
            modeContent
            
            Divider()
            
            // Footer
            footerView
        }
        .frame(width: 650, height: 580)
        .onAppear {
            initializeState()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Image(systemName: "circle.circle")
                .foregroundColor(.blue)
            Text("编辑摇杆映射 - \(stick.displayName)")
                .font(.headline)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Mode Selector
    /// Requirements: 3.1, 5.1 - Display mode selector
    
    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("模式选择")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                ModeSelectorButton(
                    mode: .direction,
                    isSelected: selectedMode == .direction,
                    action: {
                        if selectedMode != .direction {
                            NSLog("[StickMappingEditorView] Switching to direction mode")
                            selectedMode = .direction
                            // Update stored mode (preserves existing configs)
                            onStickModeChanged?(.direction)
                        }
                    }
                )
                
                ModeSelectorButton(
                    mode: .mouse,
                    isSelected: selectedMode == .mouse,
                    action: {
                        if selectedMode != .mouse {
                            NSLog("[StickMappingEditorView] Switching to mouse mode")
                            selectedMode = .mouse
                            // Update stored mode (preserves existing configs)
                            onStickModeChanged?(.mouse)
                            // Apply default mouse config if none exists
                            if mouseConfig == nil {
                                applyMouseConfigChange()
                            }
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Mode Content
    /// Requirements: 3.2, 3.3, 5.2, 5.3, 5.4 - Mode-specific configuration
    
    @ViewBuilder
    private var modeContent: some View {
        switch selectedMode {
        case .direction:
            directionModeContent
        case .mouse:
            mouseModeContent
        }
    }

    // MARK: - Direction Mode Content
    /// Requirements: 3.2, 5.2, 5.3 - Direction mode with DirectionSelectorView
    
    private var directionModeContent: some View {
        DirectionSelectorView(
            stick: stick,
            currentX: currentX,
            currentY: currentY,
            configuredDirections: Set(directionMappings.keys),
            availableMacros: availableMacros,
            availableScripts: availableScripts,
            directionMappings: directionMappings,
            onMappingChanged: { direction, mapping in
                // Requirements: 5.5 - Apply changes immediately
                onDirectionMappingChanged(direction, mapping)
            },
            onDismiss: {}, // Empty - we handle dismiss at editor level
            preselectedDirection: preselectedDirection,
            showDismissControls: false // Hide dismiss controls when embedded
        )
    }
    
    // MARK: - Mouse Mode Content
    /// Requirements: 3.3, 4.1, 4.2, 4.3, 4.4, 5.4 - Mouse mode configuration
    
    private var mouseModeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("鼠标移动参数")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Reuse AxisParameterEditor for mouse mode parameters
                    /// Requirements: 4.1, 4.2, 4.3, 4.4 - Sensitivity, deadzone, curve parameters
                    AxisParameterEditor(
                        deadzone: $deadzone,
                        sensitivity: $sensitivity,
                        responseCurve: $responseCurve,
                        exponentialPower: $exponentialPower,
                        onParametersChanged: {
                            // Requirements: 5.5 - Apply changes immediately
                            applyMouseConfigChange()
                        }
                    )
                    
                    // Clear mouse mapping button
                    if mouseConfig != nil {
                        Button(role: .destructive) {
                            onMouseConfigChanged(nil)
                        } label: {
                            Label("清除鼠标映射", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer View
    
    private var footerView: some View {
        HStack {
            Button("清除所有映射") {
                clearAllMappings()
            }
            .foregroundColor(.red)
            
            Spacer()
            
            Button("完成") {
                onDismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
    
    // MARK: - State Initialization
    /// Requirements: 3.5 - Use most recently configured mode as active
    
    private func initializeState() {
        NSLog("[StickMappingEditorView] initializeState: stickMode=%@, mouseConfig=%@, directionMappings.count=%d",
              stickMode?.rawValue ?? "nil", mouseConfig != nil ? "YES" : "NO", directionMappings.count)
        
        // Load mouse config parameters if available
        if let config = mouseConfig {
            sensitivity = config.sensitivity
            deadzone = config.deadzone
            switch config.curve {
            case .linear:
                responseCurve = .linear
            case .exponential(let power):
                responseCurve = .exponential
                exponentialPower = power
            }
        }
        
        // Priority: Use explicitly stored stickMode if available
        if let explicitMode = stickMode {
            selectedMode = explicitMode
            NSLog("[StickMappingEditorView] initializeState: using explicit mode %@", explicitMode.rawValue)
            
            // If mouse mode but no mouse config, apply default
            if explicitMode == .mouse && mouseConfig == nil {
                NSLog("[StickMappingEditorView] initializeState: applying default mouse config for mouse mode")
                applyMouseConfigChange()
            }
            return
        }
        
        // Fallback: Determine initial mode based on existing configuration (backward compatibility)
        // Requirements: 3.5 - Most recently configured mode as active
        if mouseConfig != nil && directionMappings.isEmpty {
            selectedMode = .mouse
            NSLog("[StickMappingEditorView] initializeState: inferred mouse mode")
        } else {
            selectedMode = .direction
            NSLog("[StickMappingEditorView] initializeState: inferred direction mode")
        }
    }

    // MARK: - Apply Mouse Config Change
    /// Requirements: 5.5 - Apply changes immediately without save action
    
    private func applyMouseConfigChange() {
        let curve: ResponseCurve = responseCurve == .linear 
            ? .linear 
            : .exponential(power: exponentialPower)
        
        let config = MouseMoveAction(
            sensitivity: sensitivity,
            deadzone: deadzone,
            curve: curve
        )
        
        onMouseConfigChanged(config)
    }
    
    // MARK: - Clear All Mappings
    
    private func clearAllMappings() {
        // Clear all direction mappings
        for direction in StickDirection.allCases {
            onDirectionMappingChanged(direction, nil)
        }
        
        // Clear mouse config
        onMouseConfigChanged(nil)
    }
}

// MARK: - Mode Selector Button

struct ModeSelectorButton: View {
    let mode: StickMappingMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.title2)
                Text(mode.displayName)
                    .font(.body)
            }
            .frame(width: 140, height: 50)
            .background(isSelected ? mode.color.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? mode.color : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

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
        )
    ]
    
    return StickMappingEditorView(
        stick: .left,
        currentX: 0.0,
        currentY: 0.0,
        directionMappings: sampleDirectionMappings,
        mouseConfig: nil,
        availableMacros: [],
        availableScripts: [],
        onDirectionMappingChanged: { _, _ in },
        onMouseConfigChanged: { _ in },
        onDismiss: {}
    )
}
