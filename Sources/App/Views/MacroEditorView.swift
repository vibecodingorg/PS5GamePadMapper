import SwiftUI
import PS5GamePadMapperCore

/// Macro editor view with recording and scripting modes
/// Requirements: 20.1, 20.2, 20.3, 20.4, 20.5, 20.6, 20.7
struct MacroEditorView: View {
    @Binding var macro: Macro?
    @Binding var script: Script?
    let onSave: (Macro?, Script?) -> Void
    
    @State private var editorMode: MacroEditorMode = .recording
    @State private var macroName: String = ""
    @State private var macroType: MacroType = .sequence
    @State private var loopInterval: Int = 100
    @State private var loopMaxCount: Int = 0
    @State private var whileCondition: String = ""
    @State private var conditionError: String? = nil
    
    // Recording state
    @StateObject private var recorder = MacroRecorder()
    
    // Script state
    @State private var scriptName: String = ""
    @State private var scriptSource: String = ""
    @State private var scriptError: ScriptValidationError? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Mode selector
            modeSelectorView
            
            Divider()
            
            // Content based on mode
            ScrollView {
                switch editorMode {
                case .recording:
                    recordingModeView
                case .script:
                    scriptModeView
                }
            }
            
            Divider()
            
            // Footer
            footerView
        }
        .frame(width: 550, height: 600)
        .onAppear {
            loadExistingData()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text(macro != nil || script != nil ? "编辑宏/脚本" : "创建宏/脚本")
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
    
    // MARK: - Mode Selector
    
    private var modeSelectorView: some View {
        Picker("编辑模式", selection: $editorMode) {
            ForEach(MacroEditorMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    
    // MARK: - Recording Mode View
    /// Requirements: 20.1, 20.2, 20.3 - Recording mode with keyboard/mouse capture and timing
    
    private var recordingModeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Macro name
            VStack(alignment: .leading, spacing: 4) {
                Text("宏名称")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("输入宏名称", text: $macroName)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Macro type selector
            /// Requirements: 4.1 - Support whileCondition type with condition expression
            VStack(alignment: .leading, spacing: 4) {
                Text("宏类型")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("类型", selection: $macroType) {
                    Text("序列").tag(MacroType.sequence)
                    Text("循环 (连发)").tag(MacroType.loop(interval: loopInterval, maxCount: loopMaxCount))
                    Text("切换").tag(MacroType.toggle)
                    Text("条件循环").tag(MacroType.whileCondition(condition: whileCondition))
                }
                .pickerStyle(.segmented)
            }
            
            // Loop parameters (if loop type selected)
            if case .loop = macroType {
                loopParametersView
            }
            
            // While condition parameters (if whileCondition type selected)
            /// Requirements: 4.1 - Add UI for creating whileCondition macros
            if case .whileCondition = macroType {
                whileConditionParametersView
            }
            
            Divider()
            
            // Recording controls
            /// Requirements: 20.3 - Provide start, stop, clear controls
            recordingControlsView
            
            Divider()
            
            // Recorded steps list
            /// Requirements: 20.4, 20.5 - Allow modifying delay values and deleting steps
            recordedStepsView
        }
        .padding()
    }
    
    private var loopParametersView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("间隔 (毫秒):")
                TextField("", value: $loopInterval, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Stepper("", value: $loopInterval, in: 10...5000, step: 10)
                    .labelsHidden()
            }
            
            HStack {
                Text("最大次数 (0 = 无限):")
                TextField("", value: $loopMaxCount, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Stepper("", value: $loopMaxCount, in: 0...1000)
                    .labelsHidden()
            }
        }
        .onChange(of: loopInterval) { newValue in
            macroType = .loop(interval: newValue, maxCount: loopMaxCount)
        }
        .onChange(of: loopMaxCount) { newValue in
            macroType = .loop(interval: loopInterval, maxCount: newValue)
        }
    }
    
    /// While condition parameters view
    /// Requirements: 4.1 - Add condition expression input field
    private var whileConditionParametersView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("条件表达式")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                
                // Condition validation indicator
                if let error = conditionError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } else if !whileCondition.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("条件有效")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            TextField("例如: isButtonPressed(cross) || isButtonPressed(circle)", text: $whileCondition)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onChange(of: whileCondition) { newValue in
                    validateCondition(newValue)
                    macroType = .whileCondition(condition: newValue)
                }
            
            // Condition syntax help
            VStack(alignment: .leading, spacing: 4) {
                Text("支持的语法:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        conditionHelpTag("isButtonPressed(button)")
                        conditionHelpTag("&&")
                        conditionHelpTag("||")
                        conditionHelpTag("!")
                        conditionHelpTag("true")
                        conditionHelpTag("false")
                    }
                }
                
                Text("按钮: cross, circle, square, triangle, l1, r1, l2, r2, l3, r3, options, share, ps, touchpad, dpadUp, dpadDown, dpadLeft, dpadRight")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }
    
    /// Helper view for condition syntax tags
    private func conditionHelpTag(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(4)
    }
    
    /// Validate condition expression
    private func validateCondition(_ condition: String) {
        guard !condition.isEmpty else {
            conditionError = nil
            return
        }
        
        let parser = ScriptParser()
        do {
            _ = try parser.parseCondition(condition)
            conditionError = nil
        } catch {
            conditionError = "条件无效"
        }
    }
    
    /// Requirements: 20.3 - Provide controls to start, stop, and clear the recording
    private var recordingControlsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("录制")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                // Start/Stop button
                Button(action: {
                    if recorder.isRecording {
                        recorder.stopRecording()
                    } else {
                        recorder.startRecording()
                    }
                }) {
                    HStack {
                        Image(systemName: recorder.isRecording ? "stop.fill" : "record.circle")
                            .foregroundColor(recorder.isRecording ? .red : .primary)
                        Text(recorder.isRecording ? "停止" : "开始录制")
                    }
                    .frame(minWidth: 140)
                }
                .buttonStyle(.bordered)
                .tint(recorder.isRecording ? .red : .accentColor)
                
                // Clear button
                Button(action: {
                    recorder.clearSteps()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清除")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(recorder.steps.isEmpty || recorder.isRecording)
                
                Spacer()
                
                // Recording indicator
                if recorder.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("录制中...")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            if recorder.isRecording {
                Text("按下键盘或点击鼠标按钮进行录制。输入之间的时间间隔将被记录为延迟。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    
    /// Requirements: 20.4, 20.5 - Allow modifying delay values and deleting individual steps
    private var recordedStepsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("已录制步骤 (\(recorder.steps.count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            if recorder.steps.isEmpty {
                Text("尚未录制任何步骤。开始录制以捕获输入。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.vertical, 20)
            } else {
                List {
                    ForEach(Array(recorder.steps.enumerated()), id: \.offset) { index, step in
                        MacroStepRow(
                            step: step,
                            index: index,
                            onDelayChanged: { newDelay in
                                recorder.updateDelay(at: index, milliseconds: newDelay)
                            },
                            onDelete: {
                                recorder.deleteStep(at: index)
                            }
                        )
                    }
                }
                .listStyle(.bordered)
                .frame(minHeight: 200)
            }
        }
    }
    
    // MARK: - Script Mode View
    /// Requirements: 20.6, 20.7 - Script mode with text editor and syntax error indicator
    
    private var scriptModeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Script name
            VStack(alignment: .leading, spacing: 4) {
                Text("脚本名称")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("输入脚本名称", text: $scriptName)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Script editor
            /// Requirements: 20.6 - Provide a text editor for entering macro scripts
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("脚本源码")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    
                    // Syntax error indicator
                    /// Requirements: 20.7 - Display an error indicator when script contains syntax errors
                    if let error = scriptError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error.message)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else if !scriptSource.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("语法正确")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                ScriptTextEditor(
                    source: $scriptSource,
                    error: $scriptError
                )
                .frame(minHeight: 250)
            }
            
            // API reference
            scriptAPIReferenceView
        }
        .padding()
    }
    
    private var scriptAPIReferenceView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("可用函数")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ScriptAPIFunction.allCases) { func_ in
                        Text(func_.signature)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            Button("取消") {
                dismiss()
            }
            
            Spacer()
            
            Button("保存") {
                saveAndDismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private var canSave: Bool {
        switch editorMode {
        case .recording:
            let hasBasicRequirements = !macroName.isEmpty && !recorder.steps.isEmpty
            // For whileCondition, also require a valid condition
            if case .whileCondition = macroType {
                return hasBasicRequirements && !whileCondition.isEmpty && conditionError == nil
            }
            return hasBasicRequirements
        case .script:
            return !scriptName.isEmpty && !scriptSource.isEmpty && scriptError == nil
        }
    }
    
    private func loadExistingData() {
        if let existingMacro = macro {
            macroName = existingMacro.name
            macroType = existingMacro.type
            recorder.loadSteps(existingMacro.steps)
            
            if case .loop(let interval, let maxCount) = existingMacro.type {
                loopInterval = interval
                loopMaxCount = maxCount
            }
            
            // Load whileCondition parameters
            /// Requirements: 4.1 - Support editing whileCondition macros
            if case .whileCondition(let condition) = existingMacro.type {
                whileCondition = condition
                validateCondition(condition)
            }
            
            editorMode = .recording
        }
        
        if let existingScript = script {
            scriptName = existingScript.name
            scriptSource = existingScript.source
            editorMode = .script
        }
    }
    
    private func saveAndDismiss() {
        switch editorMode {
        case .recording:
            let finalType: MacroType
            if case .loop = macroType {
                finalType = .loop(interval: loopInterval, maxCount: loopMaxCount)
            } else if case .whileCondition = macroType {
                // Requirements: 4.1 - Save whileCondition with condition expression
                finalType = .whileCondition(condition: whileCondition)
            } else {
                finalType = macroType
            }
            
            let newMacro = Macro(
                id: macro?.id ?? UUID(),
                name: macroName,
                steps: recorder.steps,
                type: finalType
            )
            onSave(newMacro, nil)
            
        case .script:
            let newScript = Script(
                id: script?.id ?? UUID(),
                name: scriptName,
                source: scriptSource
            )
            onSave(nil, newScript)
        }
        
        dismiss()
    }
}


// MARK: - Supporting Types

enum MacroEditorMode: String, CaseIterable, Identifiable {
    case recording = "录制"
    case script = "脚本"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
}

/// Script validation error
struct ScriptValidationError: Equatable {
    let line: Int
    let message: String
}

/// Script API function reference
enum ScriptAPIFunction: String, CaseIterable, Identifiable {
    case pressKey
    case releaseKey
    case tapKey
    case mouseClick
    case mouseMove
    case sleep
    case isButtonPressed
    
    var id: String { rawValue }
    
    var signature: String {
        switch self {
        case .pressKey: return "pressKey(key)"
        case .releaseKey: return "releaseKey(key)"
        case .tapKey: return "tapKey(key, ms)"
        case .mouseClick: return "mouseClick(button)"
        case .mouseMove: return "mouseMove(dx, dy)"
        case .sleep: return "sleep(ms)"
        case .isButtonPressed: return "isButtonPressed(btn)"
        }
    }
}

// MARK: - Macro Recorder

/// Handles recording of keyboard and mouse inputs as macro steps
/// Requirements: 20.1, 20.2 - Capture keyboard/mouse inputs and timing as steps
@MainActor
class MacroRecorder: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var steps: [MacroStep] = []
    
    private var lastEventTime: Date?
    private var eventMonitor: Any?
    
    /// Start recording keyboard and mouse inputs
    /// Requirements: 20.1 - Capture keyboard and mouse inputs as macro steps
    func startRecording() {
        guard !isRecording else { return }
        
        isRecording = true
        lastEventTime = Date()
        
        // Monitor keyboard events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
    }
    
    /// Stop recording
    func stopRecording() {
        guard isRecording else { return }
        
        isRecording = false
        lastEventTime = nil
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    /// Clear all recorded steps
    func clearSteps() {
        steps.removeAll()
    }
    
    /// Load existing steps (for editing)
    func loadSteps(_ existingSteps: [MacroStep]) {
        steps = existingSteps
    }
    
    /// Update delay value at specific index
    /// Requirements: 20.4 - Allow modifying delay values
    func updateDelay(at index: Int, milliseconds: Int) {
        guard index < steps.count else { return }
        if case .delay = steps[index] {
            steps[index] = .delay(milliseconds: max(1, min(10000, milliseconds)))
        }
    }
    
    /// Delete step at specific index
    /// Requirements: 20.5 - Allow deleting individual steps
    func deleteStep(at index: Int) {
        guard index < steps.count else { return }
        steps.remove(at: index)
    }
    
    /// Handle incoming event during recording
    /// Requirements: 20.2 - Capture timing between inputs as delay steps
    private func handleEvent(_ event: NSEvent) {
        // Calculate delay since last event
        if let lastTime = lastEventTime {
            let delay = Int(Date().timeIntervalSince(lastTime) * 1000)
            if delay > 10 { // Only add delay if > 10ms
                steps.append(.delay(milliseconds: delay))
            }
        }
        lastEventTime = Date()
        
        // Record the event
        switch event.type {
        case .keyDown:
            // Ignore modifier-only keys
            let modifierOnlyKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            if !modifierOnlyKeyCodes.contains(event.keyCode) {
                steps.append(.keyDown(keyCode: event.keyCode))
                // Auto-add key up after key down
                steps.append(.keyUp(keyCode: event.keyCode))
            }
            
        case .leftMouseDown:
            steps.append(.mouseClick(button: .left))
            
        case .rightMouseDown:
            steps.append(.mouseClick(button: .right))
            
        case .otherMouseDown:
            steps.append(.mouseClick(button: .middle))
            
        default:
            break
        }
    }
}


// MARK: - Macro Step Row

/// Row view for displaying and editing a single macro step
/// Requirements: 20.4, 20.5 - Allow modifying delay values and deleting steps
struct MacroStepRow: View {
    let step: MacroStep
    let index: Int
    let onDelayChanged: (Int) -> Void
    let onDelete: () -> Void
    
    @State private var delayValue: Int = 0
    
    var body: some View {
        HStack {
            // Step number
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            // Step icon
            Image(systemName: stepIcon)
                .foregroundColor(stepColor)
                .frame(width: 20)
            
            // Step description
            if case .delay(let ms) = step {
                // Editable delay
                /// Requirements: 20.4 - Allow modifying delay values
                HStack {
                    Text("延迟:")
                    TextField("", value: $delayValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .onAppear { delayValue = ms }
                        .onChange(of: delayValue) { newValue in
                            onDelayChanged(newValue)
                        }
                    Text("毫秒")
                        .foregroundColor(.secondary)
                }
            } else {
                Text(stepDescription)
                    .font(.system(.body, design: .monospaced))
            }
            
            Spacer()
            
            // Delete button
            /// Requirements: 20.5 - Allow deleting individual steps
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    private var stepIcon: String {
        switch step {
        case .keyDown: return "arrow.down.square"
        case .keyUp: return "arrow.up.square"
        case .mouseClick: return "cursorarrow.click"
        case .mouseMove: return "cursorarrow.motionlines"
        case .delay: return "clock"
        }
    }
    
    private var stepColor: Color {
        switch step {
        case .keyDown: return .blue
        case .keyUp: return .cyan
        case .mouseClick: return .green
        case .mouseMove: return .orange
        case .delay: return .gray
        }
    }
    
    private var stepDescription: String {
        switch step {
        case .keyDown(let keyCode):
            return "按下键: \(KeyCodeHelper.keyName(for: keyCode))"
        case .keyUp(let keyCode):
            return "释放键: \(KeyCodeHelper.keyName(for: keyCode))"
        case .mouseClick(let button):
            return "鼠标点击: \(button.rawValue)"
        case .mouseMove(let dx, let dy):
            return "鼠标移动: (\(dx), \(dy))"
        case .delay(let ms):
            return "延迟: \(ms)毫秒"
        }
    }
}

// MARK: - Script Text Editor

/// Text editor for script source with syntax validation
/// Requirements: 20.6, 20.7 - Text editor with syntax error indicator
struct ScriptTextEditor: View {
    @Binding var source: String
    @Binding var error: ScriptValidationError?
    
    var body: some View {
        TextEditor(text: $source)
            .font(.system(.body, design: .monospaced))
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(error != nil ? Color.red : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .onChange(of: source) { newValue in
                validateScript(newValue)
            }
    }
    
    /// Validate script syntax
    /// Requirements: 20.7 - Display syntax error indicator
    private func validateScript(_ source: String) {
        let engine = ScriptEngine()
        do {
            _ = try engine.parse(source)
            error = nil
        } catch let scriptError as ScriptEngine.ScriptError {
            switch scriptError {
            case .syntaxError(let line, let message):
                error = ScriptValidationError(line: line, message: "Line \(line): \(message)")
            case .unknownCommand(let command):
                error = ScriptValidationError(line: 0, message: "Unknown command: \(command)")
            case .invalidArgument(let command, let argument):
                error = ScriptValidationError(line: 0, message: "Invalid argument '\(argument)' for \(command)")
            case .executionError(let message):
                error = ScriptValidationError(line: 0, message: message)
            }
        } catch {
            self.error = ScriptValidationError(line: 0, message: error.localizedDescription)
        }
    }
}

#Preview {
    MacroEditorView(
        macro: .constant(nil),
        script: .constant(nil),
        onSave: { _, _ in }
    )
}
