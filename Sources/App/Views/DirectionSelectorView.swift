import SwiftUI
@preconcurrency import PS5GamePadMapperCore

/// Direction selector view displaying 8 direction zones with inline mapping configuration
/// Requirements: 3.1, 3.3, 3.4 - Visual interface for stick direction configuration
struct DirectionSelectorView: View {
    let stick: StickType
    let currentX: Double
    let currentY: Double
    let configuredDirections: Set<StickDirection>
    let availableMacros: [Macro]
    let availableScripts: [Script]
    let directionMappings: [StickDirection: Mapping]
    let onMappingChanged: (StickDirection, Mapping?) -> Void
    let onDismiss: () -> Void

    // Selected direction for editing
    @State private var selectedDirection: StickDirection?

    // Size constants
    private let outerRadius: CGFloat = 100
    private let innerRadius: CGFloat = 25
    private let indicatorSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 0) {
            // Left: Direction wheel
            directionWheelSection
                .frame(width: 280)

            Divider()

            // Right: Mapping configuration for selected direction
            mappingConfigSection
                .frame(minWidth: 300, maxWidth: 350)
        }
        .frame(width: 620, height: 450)
    }

    // MARK: - Direction Wheel Section

    private var directionWheelSection: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text(stick == .left ? "左摇杆方向" : "右摇杆方向")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            // Direction wheel
            ZStack {
                // Background circle
                Circle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: outerRadius * 2, height: outerRadius * 2)

                // Direction zones (visual only)
                ForEach(StickDirection.allCases, id: \.self) { direction in
                    DirectionZoneView(
                        direction: direction,
                        outerRadius: outerRadius,
                        innerRadius: innerRadius,
                        isConfigured: configuredDirections.contains(direction),
                        isActive: isDirectionActive(direction),
                        isSelected: selectedDirection == direction
                    )
                    .allowsHitTesting(false) // Disable hit testing on individual zones
                }

                // Center deadzone indicator
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: innerRadius * 2, height: innerRadius * 2)
                    .allowsHitTesting(false)

                // Current stick position indicator
                Circle()
                    .fill(Color.blue)
                    .frame(width: indicatorSize, height: indicatorSize)
                    .offset(
                        x: currentX * (outerRadius - indicatorSize / 2),
                        y: -currentY * (outerRadius - indicatorSize / 2)
                    )
                    .shadow(color: .blue.opacity(0.5), radius: 4)
                    .allowsHitTesting(false)
            }
            .frame(width: outerRadius * 2 + 20, height: outerRadius * 2 + 20)
            .contentShape(Circle())
            .onTapGesture { location in
                // Calculate which direction was tapped based on location
                let center = CGPoint(x: outerRadius + 10, y: outerRadius + 10)
                let dx = location.x - center.x
                let dy = center.y - location.y // Flip Y for standard math coordinates
                let distance = sqrt(dx * dx + dy * dy)

                // Check if tap is within the ring (between inner and outer radius)
                guard distance >= innerRadius && distance <= outerRadius else { return }

                // Calculate angle and determine direction
                var angle = atan2(dy, dx) * 180 / .pi
                if angle < 0 { angle += 360 }

                selectedDirection = directionFromAngle(angle)
            }

            // Legend
            VStack(spacing: 6) {
                HStack(spacing: 16) {
                    LegendItem(color: .green.opacity(0.5), label: "已配置")
                    LegendItem(color: .blue.opacity(0.5), label: "当前激活")
                }
                HStack(spacing: 16) {
                    LegendItem(color: .orange.opacity(0.5), label: "选中编辑")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            // Instructions
            Text("点击方向区域配置映射")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Mapping Config Section

    private var mappingConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let direction = selectedDirection {
                DirectionMappingEditor(
                    stick: stick,
                    direction: direction,
                    currentMapping: directionMappings[direction],
                    availableMacros: availableMacros,
                    availableScripts: availableScripts,
                    onMappingChanged: { mapping in
                        onMappingChanged(direction, mapping)
                    }
                )
            } else {
                // No direction selected
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("选择一个方向")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("点击左侧方向轮上的区域来配置该方向的映射")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }

    /// Check if a direction is currently active based on stick position
    private func isDirectionActive(_ direction: StickDirection) -> Bool {
        let magnitude = sqrt(currentX * currentX + currentY * currentY)
        guard magnitude > 0.3 else { return false }

        var angle = atan2(currentY, currentX) * 180 / .pi
        if angle < 0 { angle += 360 }

        let centerAngle = direction.centerAngle
        let halfZone: Double = 22.5

        var diff = abs(angle - centerAngle)
        if diff > 180 { diff = 360 - diff }

        return diff <= halfZone
    }

    /// Determine which direction corresponds to a given angle
    private func directionFromAngle(_ angle: Double) -> StickDirection {
        // Normalize angle to 0-360
        var normalizedAngle = angle
        if normalizedAngle < 0 { normalizedAngle += 360 }

        // Each direction covers 45 degrees, centered on its centerAngle
        // right: 0° (337.5 - 22.5)
        // upRight: 45° (22.5 - 67.5)
        // up: 90° (67.5 - 112.5)
        // upLeft: 135° (112.5 - 157.5)
        // left: 180° (157.5 - 202.5)
        // downLeft: 225° (202.5 - 247.5)
        // down: 270° (247.5 - 292.5)
        // downRight: 315° (292.5 - 337.5)

        if normalizedAngle >= 337.5 || normalizedAngle < 22.5 {
            return .right
        } else if normalizedAngle < 67.5 {
            return .upRight
        } else if normalizedAngle < 112.5 {
            return .up
        } else if normalizedAngle < 157.5 {
            return .upLeft
        } else if normalizedAngle < 202.5 {
            return .left
        } else if normalizedAngle < 247.5 {
            return .downLeft
        } else if normalizedAngle < 292.5 {
            return .down
        } else {
            return .downRight
        }
    }
}

/// Editor for a single direction's mapping
struct DirectionMappingEditor: View {
    let stick: StickType
    let direction: StickDirection
    let currentMapping: Mapping?
    let availableMacros: [Macro]
    let availableScripts: [Script]
    let onMappingChanged: (Mapping?) -> Void

    @State private var selectedCategory: ActionCategory = .key
    @State private var keyCode: UInt16 = 49
    @State private var keyModifiers: KeyModifiers = []
    @State private var isCapturingKey: Bool = false
    @State private var mouseButton: MouseButton = .left
    @State private var selectedMacroId: UUID?
    @State private var selectedScriptId: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .foregroundColor(.blue)
                    Text("\(stick.displayName) - \(direction.displayName)")
                        .font(.headline)
                }

                Divider()

                // Action type selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("动作类型")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(ActionCategory.allCases) { category in
                            ActionCategoryButton(
                                category: category,
                                isSelected: selectedCategory == category,
                                action: {
                                    selectedCategory = category
                                    applyMappingChange()
                                }
                            )
                        }
                    }
                }

                Divider()

                // Action configuration
                actionConfigurationSection

                Spacer()

                // Clear button
                if currentMapping != nil {
                    Button(role: .destructive) {
                        onMappingChanged(nil)
                    } label: {
                        Label("清除此方向映射", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .onAppear {
            loadCurrentMapping()
        }
        .onChange(of: direction) { _ in
            loadCurrentMapping()
        }
    }

    @ViewBuilder
    private var actionConfigurationSection: some View {
        switch selectedCategory {
        case .key:
            keyActionConfiguration
        case .mouse:
            mouseActionConfiguration
        case .macro:
            macroActionConfiguration
        case .script:
            scriptActionConfiguration
        }
    }

    private var keyActionConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("按键配置")
                .font(.subheadline)
                .foregroundColor(.secondary)

            KeyCaptureView(
                keyCode: $keyCode,
                modifiers: $keyModifiers,
                isCapturing: $isCapturingKey,
                onKeyChanged: { applyMappingChange() }
            )

            ModifierKeysSelector(
                modifiers: $keyModifiers,
                onModifiersChanged: { applyMappingChange() }
            )
        }
    }

    private var mouseActionConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("鼠标按钮")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker("按钮", selection: $mouseButton) {
                ForEach([MouseButton.left, .right, .middle], id: \.self) { button in
                    Text(button.displayName).tag(button)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: mouseButton) { _ in
                applyMappingChange()
            }
        }
    }

    private var macroActionConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择宏")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if availableMacros.isEmpty {
                Text("暂无可用宏")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                Picker("选择宏", selection: $selectedMacroId) {
                    Text("无").tag(nil as UUID?)
                    ForEach(availableMacros) { macro in
                        Text(macro.name).tag(macro.id as UUID?)
                    }
                }
                .onChange(of: selectedMacroId) { _ in
                    applyMappingChange()
                }
            }
        }
    }

    private var scriptActionConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择脚本")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if availableScripts.isEmpty {
                Text("暂无可用脚本")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                Picker("选择脚本", selection: $selectedScriptId) {
                    Text("无").tag(nil as UUID?)
                    ForEach(availableScripts) { script in
                        Text(script.name).tag(script.id as UUID?)
                    }
                }
                .onChange(of: selectedScriptId) { _ in
                    applyMappingChange()
                }
            }
        }
    }

    private func loadCurrentMapping() {
        guard let mapping = currentMapping else {
            // Reset to defaults
            selectedCategory = .key
            keyCode = 49
            keyModifiers = []
            mouseButton = .left
            selectedMacroId = nil
            selectedScriptId = nil
            return
        }

        switch mapping.action {
        case .keyPress(let keyAction), .keyRelease(let keyAction):
            selectedCategory = .key
            keyCode = keyAction.keyCode
            keyModifiers = keyAction.modifiers

        case .mouseButton(let mouseAction):
            selectedCategory = .mouse
            mouseButton = mouseAction.button

        case .macro(let macro):
            selectedCategory = .macro
            selectedMacroId = macro.id

        case .script(let script):
            selectedCategory = .script
            selectedScriptId = script.id

        default:
            selectedCategory = .key
        }
    }

    private func applyMappingChange() {
        let action = buildAction()
        guard let action = action else {
            onMappingChanged(nil)
            return
        }

        let input = InputSource.direction(DirectionInput(stick: stick, direction: direction))
        let mapping = Mapping(input: input, trigger: .press, action: action)
        onMappingChanged(mapping)
    }

    private func buildAction() -> Action? {
        switch selectedCategory {
        case .key:
            let keyAction = KeyAction(keyCode: keyCode, modifiers: keyModifiers)
            return .keyPress(keyAction)

        case .mouse:
            return .mouseButton(MouseButtonAction(button: mouseButton))

        case .macro:
            guard let macroId = selectedMacroId,
                  let macro = availableMacros.first(where: { $0.id == macroId }) else {
                return nil
            }
            return .macro(macro)

        case .script:
            guard let scriptId = selectedScriptId,
                  let script = availableScripts.first(where: { $0.id == scriptId }) else {
                return nil
            }
            return .script(script)
        }
    }
}

/// Individual direction zone in the selector (visual only, hit testing handled by parent)
struct DirectionZoneView: View {
    let direction: StickDirection
    let outerRadius: CGFloat
    let innerRadius: CGFloat
    let isConfigured: Bool
    let isActive: Bool
    let isSelected: Bool

    var body: some View {
        DirectionZoneShape(
            direction: direction,
            outerRadius: outerRadius,
            innerRadius: innerRadius
        )
        .fill(zoneColor)
        .overlay(
            DirectionZoneShape(
                direction: direction,
                outerRadius: outerRadius,
                innerRadius: innerRadius
            )
            .stroke(strokeColor, lineWidth: isSelected ? 3 : (isActive ? 2 : 1))
        )
        .overlay(
            directionLabel
                .position(labelPosition)
        )
        .frame(width: outerRadius * 2, height: outerRadius * 2)
    }

    private var zoneColor: Color {
        if isSelected {
            return Color.orange.opacity(0.5)
        } else if isActive {
            return Color.blue.opacity(0.5)
        } else if isConfigured {
            return Color.green.opacity(0.3)
        } else {
            return Color.gray.opacity(0.1)
        }
    }

    private var strokeColor: Color {
        if isSelected {
            return Color.orange
        } else if isActive {
            return Color.blue
        } else {
            return Color.gray.opacity(0.3)
        }
    }

    private var directionLabel: some View {
        Text(direction.shortLabel)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(isSelected || isActive ? .white : (isConfigured ? .green : .secondary))
    }

    private var labelPosition: CGPoint {
        let labelRadius = (outerRadius + innerRadius) / 2
        let angle = CGFloat(direction.centerAngle * .pi / 180)
        return CGPoint(
            x: outerRadius + CoreGraphics.cos(angle) * labelRadius,
            y: outerRadius - CoreGraphics.sin(angle) * labelRadius
        )
    }
}

/// Shape for a direction zone (pie slice)
struct DirectionZoneShape: Shape {
    let direction: StickDirection
    let outerRadius: CGFloat
    let innerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: outerRadius, y: outerRadius)

        let centerAngle = direction.centerAngle
        let halfZone: Double = 22.5

        let startAngle = Angle(degrees: -(centerAngle + halfZone))
        let endAngle = Angle(degrees: -(centerAngle - halfZone))

        path.addArc(center: center, radius: outerRadius,
                    startAngle: startAngle, endAngle: endAngle, clockwise: true)

        path.addArc(center: center, radius: innerRadius,
                    startAngle: endAngle, endAngle: startAngle, clockwise: false)

        path.closeSubpath()
        return path
    }
}

/// Legend item for the direction selector
struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
        }
    }
}

// MARK: - StickDirection Extensions

extension StickDirection {
    var shortLabel: String {
        switch self {
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        case .upLeft: return "↖"
        case .upRight: return "↗"
        case .downLeft: return "↙"
        case .downRight: return "↘"
        }
    }
}

#Preview {
    DirectionSelectorView(
        stick: .left,
        currentX: 0.5,
        currentY: 0.5,
        configuredDirections: [.up, .down, .left, .right],
        availableMacros: [],
        availableScripts: [],
        directionMappings: [:],
        onMappingChanged: { _, _ in },
        onDismiss: {}
    )
}
