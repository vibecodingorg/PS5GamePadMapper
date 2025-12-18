import SwiftUI
import AppKit
import PS5GamePadMapperCore

/// Macro editor view with recording and scripting modes
/// Requirements: 20.1, 20.2, 20.3, 20.4, 20.5, 20.6, 20.7
struct MacroEditorView: View {
    @Binding var macro: Macro?
    @Binding var script: Script?
    let onSave: (Macro?, Script?) -> Void
    let onCancel: () -> Void
    
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
        .onDisappear {
            recorder.stopRecording()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text(macro != nil || script != nil ? "编辑宏/脚本" : "创建宏/脚本")
                .font(.headline)
            Spacer()
            Button(action: { onCancel() }) {
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
    
    private var recordingModeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Macro name - pure SwiftUI TextField
            VStack(alignment: .leading, spacing: 4) {
                Text("宏名称")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("输入宏名称", text: $macroName)
                    .textFieldStyle(.roundedBorder)
                    .disabled(recorder.isRecording)
            }
            
            // Macro type selector
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
            
            // Loop parameters
            if case .loop = macroType {
                loopParametersView
            }
            
            // While condition parameters
            if case .whileCondition = macroType {
                whileConditionParametersView
            }
            
            Divider()
            
            // Recording controls
            recordingControlsView
            
            Divider()
            
            // Recorded steps list
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
    
    private var whileConditionParametersView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("条件表达式")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                
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
                .disabled(recorder.isRecording)
                .onChange(of: whileCondition) { newValue in
                    validateCondition(newValue)
                    macroType = .whileCondition(condition: newValue)
                }
            
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
    
    private func conditionHelpTag(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(4)
    }
    
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
    
    private var recordingControlsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("录制")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
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
    
    private var scriptModeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Script name - pure SwiftUI TextField
            VStack(alignment: .leading, spacing: 4) {
                Text("脚本名称")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("输入脚本名称", text: $scriptName)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Script editor - pure SwiftUI TextEditor
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("脚本源码")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    
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
                
                // Pure SwiftUI TextEditor
                TextEditor(text: $scriptSource)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 250)
                    .border(Color.gray.opacity(0.3), width: 1)
                    .onChange(of: scriptSource) { newValue in
                        validateScript(newValue)
                    }
            }
            
            // API reference
            scriptAPIReferenceView
        }
        .padding()
    }
    
    private func validateScript(_ source: String) {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            scriptError = nil
            return
        }
        
        let engine = ScriptEngine()
        do {
            _ = try engine.parse(source)
            scriptError = nil
        } catch let scriptError as ScriptEngine.ScriptError {
            switch scriptError {
            case .syntaxError(let line, let message):
                self.scriptError = ScriptValidationError(line: line, message: "Line \(line): \(message)")
            case .unknownCommand(let command):
                self.scriptError = ScriptValidationError(line: 0, message: "Unknown command: \(command)")
            case .invalidArgument(let command, let argument):
                self.scriptError = ScriptValidationError(line: 0, message: "Invalid argument '\(argument)' for \(command)")
            case .executionError(let message):
                self.scriptError = ScriptValidationError(line: 0, message: message)
            }
        } catch {
            self.scriptError = ScriptValidationError(line: 0, message: error.localizedDescription)
        }
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
                onCancel()
            }
            
            Spacer()
            
            Button("保存") {
                saveAndClose()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
        }
        .padding()
    }
    
    private var canSave: Bool {
        switch editorMode {
        case .recording:
            let hasBasicRequirements = !macroName.isEmpty && !recorder.steps.isEmpty
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
    
    private func saveAndClose() {
        switch editorMode {
        case .recording:
            let finalType: MacroType
            if case .loop = macroType {
                finalType = .loop(interval: loopInterval, maxCount: loopMaxCount)
            } else if case .whileCondition = macroType {
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
            print("[MacroEditorView] Saving macro: name=\(newMacro.name), id=\(newMacro.id), steps=\(newMacro.steps.count)")
            onSave(newMacro, nil)
            
        case .script:
            let newScript = Script(
                id: script?.id ?? UUID(),
                name: scriptName,
                source: scriptSource
            )
            print("[MacroEditorView] Saving script: name=\(newScript.name), id=\(newScript.id)")
            onSave(nil, newScript)
        }
        
        onCancel()
    }
}

// MARK: - Supporting Types

enum MacroEditorMode: String, CaseIterable, Identifiable {
    case recording = "录制"
    case script = "脚本"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
}

struct ScriptValidationError: Equatable {
    let line: Int
    let message: String
}

enum ScriptAPIFunction: String, CaseIterable, Identifiable {
    case pressKey, releaseKey, tapKey, mouseClick, mouseMove, sleep, isButtonPressed
    
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

@MainActor
class MacroRecorder: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var steps: [MacroStep] = []
    
    private var lastEventTime: Date?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    
    func startRecording() {
        guard !isRecording else { return }
        
        isRecording = true
        lastEventTime = Date()
        
        // Local monitor for keyboard events only (let mouse events pass through for UI interaction)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            Task { @MainActor in
                self?.handleEvent(event)
            }
            // Consume keyboard events so they don't go to text fields
            return nil
        }
        
        // Global monitor for all events when app is not active
        let globalEventMask: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: globalEventMask) { [weak self] event in
            Task { @MainActor in
                self?.handleEvent(event)
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        isRecording = false
        lastEventTime = nil
        
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }
    
    func clearSteps() {
        steps.removeAll()
    }
    
    func loadSteps(_ existingSteps: [MacroStep]) {
        steps = existingSteps
    }
    
    func updateDelay(at index: Int, milliseconds: Int) {
        guard index < steps.count else { return }
        if case .delay = steps[index] {
            steps[index] = .delay(milliseconds: max(1, min(10000, milliseconds)))
        }
    }
    
    func deleteStep(at index: Int) {
        guard index < steps.count else { return }
        steps.remove(at: index)
    }
    
    private func handleEvent(_ event: NSEvent) {
        if let lastTime = lastEventTime {
            let delay = Int(Date().timeIntervalSince(lastTime) * 1000)
            if delay > 10 {
                steps.append(.delay(milliseconds: delay))
            }
        }
        lastEventTime = Date()
        
        switch event.type {
        case .keyDown:
            let modifierOnlyKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            if !modifierOnlyKeyCodes.contains(event.keyCode) {
                steps.append(.keyDown(keyCode: event.keyCode))
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

struct MacroStepRow: View {
    let step: MacroStep
    let index: Int
    let onDelayChanged: (Int) -> Void
    let onDelete: () -> Void
    
    @State private var delayValue: Int = 0
    
    var body: some View {
        HStack {
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Image(systemName: stepIcon)
                .foregroundColor(stepColor)
                .frame(width: 20)
            
            if case .delay(let ms) = step {
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

#Preview {
    MacroEditorView(
        macro: .constant(nil),
        script: .constant(nil),
        onSave: { _, _ in },
        onCancel: {}
    )
}
