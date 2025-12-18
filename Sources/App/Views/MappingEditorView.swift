import SwiftUI
import PS5GamePadMapperCore

/// Action type categories for mapping configuration
/// Requirements: 19.1 - Provide options to select action type: Key, Mouse, Macro, or Script
enum ActionCategory: String, CaseIterable, Identifiable {
    case key = "按键"
    case mouse = "鼠标"
    case macro = "宏"
    case script = "脚本"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .key: return "keyboard"
        case .mouse: return "computermouse"
        case .macro: return "list.bullet.rectangle"
        case .script: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

/// Main mapping editor view
/// Requirements: 19.1, 19.2 - Action type selector with immediate apply on change
struct MappingEditorView: View {
    let input: InputSource
    let currentMapping: Mapping?
    let availableMacros: [Macro]
    let availableScripts: [Script]
    let onMappingChanged: (Mapping?) -> Void
    
    @State private var selectedCategory: ActionCategory = .key
    @State private var selectedTriggerMode: TriggerModeOption = .press
    @State private var holdThreshold: Double = 0.5
    
    // Key action state
    @State private var keyCode: UInt16 = 49 // Space
    @State private var keyModifiers: KeyModifiers = []
    @State private var isCapturingKey: Bool = false
    
    // Mouse action state
    @State private var mouseButton: MouseButton = .left
    @State private var scrollDirection: ScrollDirection = .up
    @State private var scrollAmount: Double = 1.0
    @State private var mouseActionType: MouseActionType = .click
    
    // Axis parameters state
    @State private var deadzone: Double = 0.1
    @State private var sensitivity: Double = 1.0
    @State private var responseCurve: ResponseCurveOption = .linear
    @State private var exponentialPower: Double = 2.0
    
    // Macro/Script selection state
    @State private var selectedMacroId: UUID?
    @State private var selectedScriptId: UUID?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Input info
                    inputInfoSection
                    
                    Divider()
                    
                    // Trigger mode selector
                    triggerModeSection
                    
                    Divider()
                    
                    // Action type selector
                    actionTypeSection
                    
                    Divider()
                    
                    // Action configuration based on selected category
                    actionConfigurationSection
                }
                .padding()
            }
            
            Divider()
            
            // Footer with buttons
            footerView
        }
        .frame(width: 450, height: 550)
        .onAppear {
            print("[MappingEditorView] onAppear - availableMacros: \(availableMacros.count), availableScripts: \(availableScripts.count)")
            loadCurrentMapping()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text("编辑映射")
                .font(.headline)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    // MARK: - Input Info Section
    
    private var inputInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("输入")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: inputIcon)
                    .foregroundColor(.blue)
                Text(inputName)
                    .font(.body.bold())
            }
        }
    }
    
    private var inputName: String {
        switch input {
        case .button(let buttonType):
            return buttonType.displayName
        case .axis(let axisType):
            return axisType.displayName
        case .direction(let directionInput):
            return "\(directionInput.stick.displayName) \(directionInput.direction.displayName)"
        }
    }
    
    private var inputIcon: String {
        switch input {
        case .button:
            return "button.programmable"
        case .axis(let axisType):
            return axisType.isTrigger ? "slider.horizontal.3" : "circle.circle"
        case .direction:
            return "arrow.up.left.and.arrow.down.right"
        }
    }
    
    // MARK: - Trigger Mode Section
    
    private var triggerModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("触发模式")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("触发模式", selection: $selectedTriggerMode) {
                ForEach(TriggerModeOption.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedTriggerMode) { _ in
                applyMappingChange()
            }
            
            if selectedTriggerMode == .hold {
                HStack {
                    Text("长按时长:")
                    Slider(value: $holdThreshold, in: 0.1...3.0, step: 0.1)
                    Text("\(String(format: "%.1f", holdThreshold))秒")
                        .frame(width: 40)
                }
                .onChange(of: holdThreshold) { _ in
                    applyMappingChange()
                }
            }
        }
    }
    
    // MARK: - Action Type Section
    
    private var actionTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("动作类型")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
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
    }
    
    // MARK: - Action Configuration Section
    
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
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            Button("清除映射") {
                onMappingChanged(nil)
                dismiss()
            }
            .foregroundColor(.red)
            
            Spacer()
            
            Button("完成") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
    
    // MARK: - Key Action Configuration
    
    private var keyActionConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("按键配置")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Key capture
            KeyCaptureView(
                keyCode: $keyCode,
                modifiers: $keyModifiers,
                isCapturing: $isCapturingKey,
                onKeyChanged: { applyMappingChange() }
            )
            
            // Modifier checkboxes
            ModifierKeysSelector(
                modifiers: $keyModifiers,
                onModifiersChanged: { applyMappingChange() }
            )
        }
    }
    
    // MARK: - Mouse Action Configuration
    
    private var mouseActionConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("鼠标配置")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Mouse action type
            Picker("动作", selection: $mouseActionType) {
                ForEach(MouseActionType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: mouseActionType) { _ in
                applyMappingChange()
            }
            
            switch mouseActionType {
            case .click:
                Picker("按钮", selection: $mouseButton) {
                    ForEach([MouseButton.left, .right, .middle], id: \.self) { button in
                        Text(button.displayName).tag(button)
                    }
                }
                .onChange(of: mouseButton) { _ in
                    applyMappingChange()
                }
                
            case .scroll:
                Picker("方向", selection: $scrollDirection) {
                    ForEach([ScrollDirection.up, .down, .left, .right], id: \.self) { dir in
                        Text(dir.displayName).tag(dir)
                    }
                }
                .onChange(of: scrollDirection) { _ in
                    applyMappingChange()
                }
                
                HStack {
                    Text("滚动量:")
                    Slider(value: $scrollAmount, in: 0.5...10.0, step: 0.5)
                    Text("\(String(format: "%.1f", scrollAmount))")
                        .frame(width: 40)
                }
                .onChange(of: scrollAmount) { _ in
                    applyMappingChange()
                }
                
            case .move:
                // Axis parameters for mouse movement
                AxisParameterEditor(
                    deadzone: $deadzone,
                    sensitivity: $sensitivity,
                    responseCurve: $responseCurve,
                    exponentialPower: $exponentialPower,
                    onParametersChanged: { applyMappingChange() }
                )
            }
        }
    }
    
    // MARK: - Macro Action Configuration
    
    private var macroActionConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择宏")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if availableMacros.isEmpty {
                Text("暂无可用宏。请在宏编辑器中创建。")
                    .foregroundColor(.secondary)
                    .italic()
                    .onAppear {
                        print("[MappingEditorView] macroActionConfiguration - availableMacros is EMPTY")
                    }
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
                .onAppear {
                    print("[MappingEditorView] macroActionConfiguration - availableMacros count: \(availableMacros.count)")
                    for macro in availableMacros {
                        print("[MappingEditorView]   - Macro: \(macro.name), id: \(macro.id)")
                    }
                }
                
                if let macroId = selectedMacroId,
                   let macro = availableMacros.first(where: { $0.id == macroId }) {
                    MacroPreviewView(macro: macro)
                }
            }
        }
    }
    
    // MARK: - Script Action Configuration
    
    private var scriptActionConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择脚本")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if availableScripts.isEmpty {
                Text("暂无可用脚本。请在宏编辑器中创建。")
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
                
                if let scriptId = selectedScriptId,
                   let script = availableScripts.first(where: { $0.id == scriptId }) {
                    ScriptPreviewView(script: script)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentMapping() {
        guard let mapping = currentMapping else { return }
        
        // Load trigger mode
        switch mapping.trigger {
        case .press:
            selectedTriggerMode = .press
        case .release:
            selectedTriggerMode = .release
        case .hold(let threshold):
            selectedTriggerMode = .hold
            holdThreshold = threshold
        case .toggle:
            selectedTriggerMode = .toggle
        }
        
        // Load action
        switch mapping.action {
        case .keyPress(let keyAction), .keyRelease(let keyAction):
            selectedCategory = .key
            keyCode = keyAction.keyCode
            keyModifiers = keyAction.modifiers
            
        case .mouseButton(let mouseAction):
            selectedCategory = .mouse
            mouseActionType = .click
            mouseButton = mouseAction.button
            
        case .mouseScroll(let scrollAction):
            selectedCategory = .mouse
            mouseActionType = .scroll
            scrollDirection = scrollAction.direction
            scrollAmount = scrollAction.amount
            
        case .mouseMove(let moveAction):
            selectedCategory = .mouse
            mouseActionType = .move
            sensitivity = moveAction.sensitivity
            deadzone = moveAction.deadzone
            switch moveAction.curve {
            case .linear:
                responseCurve = .linear
            case .exponential(let power):
                responseCurve = .exponential
                exponentialPower = power
            }
            
        case .macro(let macro):
            selectedCategory = .macro
            selectedMacroId = macro.id
            
        case .script(let script):
            selectedCategory = .script
            selectedScriptId = script.id
        }
    }
    
    /// Apply mapping change immediately
    /// Requirements: 19.2 - Apply change immediately without requiring a save action
    private func applyMappingChange() {
        let triggerMode = buildTriggerMode()
        let action = buildAction()
        
        guard let action = action else {
            onMappingChanged(nil)
            return
        }
        
        let mapping = Mapping(input: input, trigger: triggerMode, action: action)
        onMappingChanged(mapping)
    }
    
    private func buildTriggerMode() -> TriggerMode {
        switch selectedTriggerMode {
        case .press:
            return .press
        case .release:
            return .release
        case .hold:
            return .hold(threshold: holdThreshold)
        case .toggle:
            return .toggle
        }
    }
    
    private func buildAction() -> Action? {
        switch selectedCategory {
        case .key:
            let keyAction = KeyAction(keyCode: keyCode, modifiers: keyModifiers)
            return .keyPress(keyAction)
            
        case .mouse:
            switch mouseActionType {
            case .click:
                return .mouseButton(MouseButtonAction(button: mouseButton))
            case .scroll:
                return .mouseScroll(MouseScrollAction(direction: scrollDirection, amount: scrollAmount))
            case .move:
                let curve: ResponseCurve = responseCurve == .linear ? .linear : .exponential(power: exponentialPower)
                return .mouseMove(MouseMoveAction(sensitivity: sensitivity, deadzone: deadzone, curve: curve))
            }
            
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

// MARK: - Supporting Types

enum TriggerModeOption: String, CaseIterable, Identifiable {
    case press = "按下"
    case release = "释放"
    case hold = "长按"
    case toggle = "切换"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
}

enum MouseActionType: String, CaseIterable, Identifiable {
    case click = "点击"
    case scroll = "滚动"
    case move = "移动"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
}

enum ResponseCurveOption: String, CaseIterable, Identifiable {
    case linear = "线性"
    case exponential = "指数"
    
    var id: String { rawValue }
}

// MARK: - Action Category Button

struct ActionCategoryButton: View {
    let category: ActionCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.title2)
                Text(category.rawValue)
                    .font(.caption)
            }
            .frame(width: 70, height: 50)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Macro Preview View

struct MacroPreviewView: View {
    let macro: Macro
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("类型: \(macro.type.description)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("步骤数: \(macro.steps.count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
    }
}

// MARK: - Script Preview View

struct ScriptPreviewView: View {
    let script: Script
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("源码预览:")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(script.source.prefix(100) + (script.source.count > 100 ? "..." : ""))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
    }
}
