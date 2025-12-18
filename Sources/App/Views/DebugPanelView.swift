import SwiftUI
import PS5GamePadMapperCore

/// Debug panel view for real-time monitoring of controller inputs and mapping actions
/// Requirements: 15.1, 15.2, 15.3, 15.4
struct DebugPanelView: View {
    @StateObject private var viewModel = DebugPanelViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with proper spacing and close button
            HStack {
                Text("调试面板")
                    .font(.headline)
                Spacer()
                Button("清除") {
                    viewModel.clearLogs()
                }
                .buttonStyle(.bordered)
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .help("关闭调试面板")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            Divider()
            
            // Main content in tabs
            TabView {
                // Input Events Tab
                inputEventsTab
                    .tabItem {
                        Label("输入事件", systemImage: "gamecontroller")
                    }
                
                // Mapping Actions Tab
                mappingActionsTab
                    .tabItem {
                        Label("动作", systemImage: "arrow.right.circle")
                    }
                
                // Macro State Tab
                macroStateTab
                    .tabItem {
                        Label("宏", systemImage: "repeat")
                    }
                
                // Axis Values Tab
                axisValuesTab
                    .tabItem {
                        Label("轴", systemImage: "slider.horizontal.3")
                    }
                
                // Direction State Tab
                /// Requirements: 8.1, 8.2, 8.3, 8.4 - Direction state display
                directionStateTab
                    .tabItem {
                        Label("方向", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    
    // MARK: - Input Events Tab
    
    /// Display real-time input events
    /// Requirements: 15.1 - Display input event within 50ms
    private var inputEventsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近输入事件")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.inputEvents) { event in
                            InputEventRow(event: event)
                        }
                    }
                }
                .onChange(of: viewModel.inputEvents.count) { _ in
                    if let lastEvent = viewModel.inputEvents.last {
                        withAnimation {
                            proxy.scrollTo(lastEvent.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Mapping Actions Tab
    
    /// Display mapping action execution
    /// Requirements: 15.2 - Display action in debug panel
    private var mappingActionsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("已执行动作")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.actionEvents) { event in
                            ActionEventRow(event: event)
                        }
                    }
                }
                .onChange(of: viewModel.actionEvents.count) { _ in
                    if let lastEvent = viewModel.actionEvents.last {
                        withAnimation {
                            proxy.scrollTo(lastEvent.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Macro State Tab
    
    /// Display macro state and current step
    /// Requirements: 15.3 - Display current macro state and step
    /// Requirements: 1.6 - Display all running macro instances
    private var macroStateTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Running instances section
            /// Requirements: 1.6 - Display all running macro instances with their states
            GroupBox("运行中的宏实例 (\(viewModel.runningInstances.count))") {
                if viewModel.runningInstances.isEmpty {
                    Text("当前没有运行中的宏")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.runningInstances) { instance in
                            RunningMacroInstanceRow(instance: instance)
                            if instance.id != viewModel.runningInstances.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Legacy single macro state (for backward compatibility)
            if viewModel.macroState.isRunning, let macroName = viewModel.macroState.currentMacroName {
                GroupBox("当前宏状态") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("状态:")
                                .foregroundColor(.secondary)
                            Text("运行中")
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("宏:")
                                .foregroundColor(.secondary)
                            Text(macroName)
                        }
                        
                        if let step = viewModel.macroState.currentStep {
                            HStack {
                                Text("当前步骤:")
                                    .foregroundColor(.secondary)
                                Text("\(step + 1)")
                            }
                        }
                        
                        if let totalSteps = viewModel.macroState.totalSteps {
                            HStack {
                                Text("总步骤:")
                                    .foregroundColor(.secondary)
                                Text("\(totalSteps)")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
            
            // Macro execution history
            Text("宏执行历史")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.macroEvents) { event in
                        MacroEventRow(event: event)
                    }
                }
            }
        }
    }
    
    // MARK: - Axis Values Tab
    
    /// Display axis values with 2 decimal precision
    /// Requirements: 15.4 - Show normalized value with 2 decimal precision
    private var axisValuesTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前轴值")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(AxisType.allCases, id: \.self) { axis in
                    AxisValueCard(
                        axis: axis,
                        value: viewModel.axisValues[axis] ?? 0.0
                    )
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Direction State Tab
    
    /// Display direction state for both sticks
    /// Requirements: 8.1, 8.2, 8.3, 8.4 - Direction state display and event logging
    private var directionStateTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Current direction state section
            Text("当前方向状态")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                // Left stick direction state
                StickDirectionStateCard(
                    stickName: "左摇杆",
                    state: viewModel.leftStickDirectionState
                )
                
                // Right stick direction state
                StickDirectionStateCard(
                    stickName: "右摇杆",
                    state: viewModel.rightStickDirectionState
                )
            }
            
            Divider()
            
            // Direction events log section
            Text("方向事件日志")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.directionEvents) { event in
                            InputEventRow(event: event)
                        }
                    }
                }
                .onChange(of: viewModel.directionEvents.count) { _ in
                    if let lastEvent = viewModel.directionEvents.last {
                        withAnimation {
                            proxy.scrollTo(lastEvent.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}


// MARK: - Event Row Views

/// Row view for displaying an input event
struct InputEventRow: View {
    let event: DebugInputEvent
    
    var body: some View {
        HStack(spacing: 8) {
            Text(event.timestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            
            Image(systemName: inputIcon)
                .foregroundColor(inputColor)
                .font(.caption)
            
            Text(event.inputName)
                .fontWeight(.medium)
            
            Text(event.value)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
        .id(event.id)
    }
    
    private var inputIcon: String {
        if event.isDirection {
            return "arrow.up.left.and.arrow.down.right"
        } else if event.isButton {
            return "circle.fill"
        } else {
            return "slider.horizontal.3"
        }
    }
    
    private var inputColor: Color {
        if event.isDirection {
            return .purple
        } else if event.isButton {
            return .blue
        } else {
            return .orange
        }
    }
}

/// Row view for displaying an action event
struct ActionEventRow: View {
    let event: DebugActionEvent
    
    var body: some View {
        HStack(spacing: 8) {
            Text(event.timestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            
            Image(systemName: actionIcon(for: event.actionType))
                .foregroundColor(actionColor(for: event.actionType))
                .font(.caption)
            
            Text(event.actionType)
                .fontWeight(.medium)
            
            Text(event.details)
                .foregroundColor(.secondary)
            
            // Show direction context if available
            /// Requirements: 8.4 - Log triggered actions for direction mappings
            if let directionContext = event.directionContext {
                Text("[\(directionContext)]")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
        }
        .padding(.vertical, 2)
        .id(event.id)
    }
    
    private func actionIcon(for type: String) -> String {
        switch type {
        case "KeyPress", "KeyRelease": return "keyboard"
        case "MouseButton": return "computermouse"
        case "MouseMove": return "arrow.up.left.and.arrow.down.right"
        case "MouseScroll": return "scroll"
        case "Macro": return "repeat"
        case "Script": return "doc.text"
        default: return "questionmark.circle"
        }
    }
    
    private func actionColor(for type: String) -> Color {
        switch type {
        case "KeyPress", "KeyRelease": return .blue
        case "MouseButton", "MouseMove", "MouseScroll": return .green
        case "Macro": return .purple
        case "Script": return .orange
        default: return .gray
        }
    }
}

/// Row view for displaying a macro event
struct MacroEventRow: View {
    let event: DebugMacroEvent
    
    var body: some View {
        HStack(spacing: 8) {
            Text(event.timestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            
            Circle()
                .fill(statusColor(for: event.status))
                .frame(width: 8, height: 8)
            
            Text(event.macroName)
                .fontWeight(.medium)
            
            Text(event.status)
                .foregroundColor(.secondary)
            
            if let step = event.step {
                Text("Step \(step + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .id(event.id)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "Started": return .green
        case "Completed": return .blue
        case "Interrupted": return .red
        case "Step": return .orange
        default: return .gray
        }
    }
}

/// Row view for displaying a running macro instance
/// Requirements: 1.6 - Show individual instance states
struct RunningMacroInstanceRow: View {
    let instance: RunningMacroInstanceState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                Text(instance.macroName)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(instance.macroType)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("步骤:")
                        .foregroundColor(.secondary)
                    Text("\(instance.currentStep + 1)/\(instance.totalSteps)")
                }
                .font(.caption)
                
                if instance.loopCount > 0 {
                    HStack(spacing: 4) {
                        Text("循环:")
                            .foregroundColor(.secondary)
                        Text("\(instance.loopCount)")
                    }
                    .font(.caption)
                }
                
                if instance.pressedKeysCount > 0 {
                    HStack(spacing: 4) {
                        Text("按住的键:")
                            .foregroundColor(.secondary)
                        Text("\(instance.pressedKeysCount)")
                    }
                    .font(.caption)
                }
                
                Spacer()
                
                Text(instance.id.uuidString.prefix(8))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Card view for displaying an axis value
/// Requirements: 15.4 - Show normalized value with 2 decimal precision
struct AxisValueCard: View {
    let axis: AxisType
    let value: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(axis.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                // Visual bar representation
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        
                        // Value bar
                        if axis.isTrigger {
                            // Trigger: 0.0 to 1.0, bar from left
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * CGFloat(value))
                        } else {
                            // Stick: -1.0 to 1.0, bar from center
                            let barWidth = abs(value) * geometry.size.width / 2.0
                            let barOffset = value >= 0 
                                ? geometry.size.width / 2.0 
                                : geometry.size.width / 2.0 - barWidth
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(value >= 0 ? Color.green : Color.red)
                                .frame(width: barWidth)
                                .offset(x: barOffset)
                        }
                    }
                }
                .frame(height: 20)
                
                // Numeric value with 2 decimal precision
                Text(DebugPanelViewModel.formatAxisValue(value))
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Card view for displaying stick direction state
/// Requirements: 8.1, 8.2, 8.3 - Display direction name, angle, and magnitude
struct StickDirectionStateCard: View {
    let stickName: String
    let state: StickDirectionState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Stick name header
            Text(stickName)
                .font(.headline)
            
            // Direction name
            HStack {
                Text("方向:")
                    .foregroundColor(.secondary)
                Text(state.activeDirection?.rawValue ?? "无")
                    .fontWeight(.medium)
                    .foregroundColor(state.activeDirection != nil ? .green : .secondary)
            }
            
            // Angle display
            /// Requirements: 8.2 - Show the current angle in degrees
            HStack {
                Text("角度:")
                    .foregroundColor(.secondary)
                Text(state.formattedAngle)
                    .font(.system(.body, design: .monospaced))
            }
            
            // Magnitude display
            /// Requirements: 8.3 - Show the current magnitude (0.0 to 1.0)
            HStack {
                Text("幅度:")
                    .foregroundColor(.secondary)
                Text(state.formattedMagnitude)
                    .font(.system(.body, design: .monospaced))
                
                // Visual magnitude bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.purple)
                            .frame(width: geometry.size.width * CGFloat(min(1.0, state.magnitude)))
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}


// MARK: - Data Models

/// Debug event for input
struct DebugInputEvent: Identifiable {
    let id = UUID()
    let timestamp: String
    let inputName: String
    let value: String
    let isButton: Bool
    let isDirection: Bool
    
    init(button: ButtonType, isPressed: Bool) {
        self.timestamp = Self.currentTimestamp()
        self.inputName = button.rawValue
        self.value = isPressed ? "按下" : "释放"
        self.isButton = true
        self.isDirection = false
    }
    
    init(axis: AxisType, normalizedValue: Double) {
        self.timestamp = Self.currentTimestamp()
        self.inputName = axis.rawValue
        self.value = DebugPanelAxisFormatter.formatAxisValue(normalizedValue)
        self.isButton = false
        self.isDirection = false
    }
    
    /// Initialize with direction event
    /// Requirements: 8.1, 8.4 - Display direction name and log direction events
    init(direction: DirectionEvent) {
        self.timestamp = Self.currentTimestamp()
        self.inputName = "\(direction.stick.rawValue) \(direction.direction.rawValue)"
        self.value = direction.state == .pressed ? "按下" : "释放"
        self.isButton = false
        self.isDirection = true
    }
    
    private static func currentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}

/// Debug event for action execution
struct DebugActionEvent: Identifiable {
    let id = UUID()
    let timestamp: String
    let actionType: String
    let details: String
    let directionContext: String?
    
    init(action: Action, directionContext: String? = nil) {
        self.timestamp = Self.currentTimestamp()
        self.directionContext = directionContext
        
        switch action {
        case .keyPress(let keyAction):
            self.actionType = "KeyPress"
            self.details = "Key: \(keyAction.keyCode), Modifiers: \(keyAction.modifiers.rawValue)"
        case .keyRelease(let keyAction):
            self.actionType = "KeyRelease"
            self.details = "Key: \(keyAction.keyCode)"
        case .mouseButton(let mouseAction):
            self.actionType = "MouseButton"
            self.details = "Button: \(mouseAction.button.rawValue)"
        case .mouseMove(let moveAction):
            self.actionType = "MouseMove"
            self.details = "Sensitivity: \(moveAction.sensitivity)"
        case .mouseScroll(let scrollAction):
            self.actionType = "MouseScroll"
            self.details = "Direction: \(scrollAction.direction), Amount: \(scrollAction.amount)"
        case .macro(let macro):
            self.actionType = "Macro"
            self.details = macro.name
        case .script(let script):
            self.actionType = "Script"
            self.details = script.name
        }
    }
    
    private static func currentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}

/// Debug event for macro state changes
struct DebugMacroEvent: Identifiable {
    let id = UUID()
    let timestamp: String
    let macroName: String
    let status: String
    let step: Int?
    
    init(macroName: String, status: String, step: Int? = nil) {
        self.timestamp = Self.currentTimestamp()
        self.macroName = macroName
        self.status = status
        self.step = step
    }
    
    private static func currentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}

/// Current macro state for display
struct MacroState {
    var isRunning: Bool = false
    var currentMacroName: String? = nil
    var currentStep: Int? = nil
    var totalSteps: Int? = nil
}

/// Current stick direction state for display
/// Requirements: 8.1, 8.2, 8.3 - Display direction name, angle, and magnitude
struct StickDirectionState {
    var activeDirection: StickDirection? = nil
    var angle: Double = 0.0
    var magnitude: Double = 0.0
    
    /// Formatted angle string
    var formattedAngle: String {
        DebugPanelAxisFormatter.formatAngle(angle)
    }
    
    /// Formatted magnitude string
    var formattedMagnitude: String {
        DebugPanelAxisFormatter.formatMagnitude(magnitude)
    }
    
    /// Formatted complete state string
    var formattedState: String {
        DebugPanelAxisFormatter.formatStickState(
            direction: activeDirection?.rawValue,
            angle: angle,
            magnitude: magnitude
        )
    }
}

/// State for a single running macro instance
/// Requirements: 1.6 - Display all running macro instances with their states
struct RunningMacroInstanceState: Identifiable {
    let id: UUID
    let macroName: String
    let currentStep: Int
    let totalSteps: Int
    let loopCount: Int
    let pressedKeysCount: Int
    let macroType: String
    
    init(from instance: MacroInstance) {
        self.id = instance.id
        self.macroName = instance.macro.name
        self.currentStep = instance.currentStep
        self.totalSteps = instance.macro.steps.count
        self.loopCount = instance.loopCount
        self.pressedKeysCount = instance.pressedKeys.count
        
        switch instance.macro.type {
        case .sequence:
            self.macroType = "Sequence"
        case .loop(let interval, let maxCount):
            self.macroType = maxCount > 0 ? "Loop (\(maxCount)x, \(interval)ms)" : "Loop (∞, \(interval)ms)"
        case .toggle:
            self.macroType = "Toggle"
        case .whileCondition(let condition):
            self.macroType = "While: \(condition.prefix(20))\(condition.count > 20 ? "..." : "")"
        }
    }
}


// MARK: - View Model

/// View model for the debug panel
/// Requirements: 15.1, 15.2, 15.3, 15.4
@MainActor
class DebugPanelViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var inputEvents: [DebugInputEvent] = []
    @Published var actionEvents: [DebugActionEvent] = []
    @Published var macroEvents: [DebugMacroEvent] = []
    @Published var axisValues: [AxisType: Double] = [:]
    @Published var macroState: MacroState = MacroState()
    
    /// All currently running macro instances
    /// Requirements: 1.6 - Display all running macro instances
    @Published var runningInstances: [RunningMacroInstanceState] = []
    
    /// Current direction state for left stick
    /// Requirements: 8.1, 8.2, 8.3 - Display direction name, angle, and magnitude
    @Published var leftStickDirectionState: StickDirectionState = StickDirectionState()
    
    /// Current direction state for right stick
    /// Requirements: 8.1, 8.2, 8.3 - Display direction name, angle, and magnitude
    @Published var rightStickDirectionState: StickDirectionState = StickDirectionState()
    
    /// Direction events log
    /// Requirements: 8.4 - Log direction press/release events
    @Published var directionEvents: [DebugInputEvent] = []
    
    // MARK: - Private Properties
    
    private let controllerManager: ControllerManager
    private let inputProcessor: InputProcessor
    private let maxEventCount = 100
    
    // MARK: - Initialization
    
    init() {
        self.controllerManager = ControllerManager()
        self.inputProcessor = InputProcessor()
        
        // Initialize all axis values to 0
        for axis in AxisType.allCases {
            axisValues[axis] = 0.0
        }
        
        setupCallbacks()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        controllerManager.startDiscovery()
    }
    
    func stopMonitoring() {
        controllerManager.stopDiscovery()
    }
    
    func clearLogs() {
        inputEvents.removeAll()
        actionEvents.removeAll()
        macroEvents.removeAll()
    }
    
    /// Format axis value with exactly 2 decimal places
    /// Requirements: 15.4 - Show normalized value with 2 decimal precision
    static func formatAxisValue(_ value: Double) -> String {
        return DebugPanelAxisFormatter.formatAxisValue(value)
    }
    
    // MARK: - Event Recording
    
    /// Record a button input event
    /// Requirements: 15.1 - Display input event within 50ms
    func recordButtonInput(_ button: ButtonType, isPressed: Bool) {
        let event = DebugInputEvent(button: button, isPressed: isPressed)
        addInputEvent(event)
    }
    
    /// Record an axis input event
    /// Requirements: 15.1, 15.4 - Display input event with 2 decimal precision
    func recordAxisInput(_ axis: AxisType, normalizedValue: Double) {
        axisValues[axis] = normalizedValue
        let event = DebugInputEvent(axis: axis, normalizedValue: normalizedValue)
        addInputEvent(event)
    }
    
    /// Record an action execution
    /// Requirements: 15.2 - Display action in debug panel
    func recordAction(_ action: Action) {
        let event = DebugActionEvent(action: action)
        addActionEvent(event)
    }
    
    /// Record macro state change
    /// Requirements: 15.3 - Display current macro state and step
    func recordMacroStarted(_ macroName: String, totalSteps: Int) {
        macroState.isRunning = true
        macroState.currentMacroName = macroName
        macroState.currentStep = 0
        macroState.totalSteps = totalSteps
        
        let event = DebugMacroEvent(macroName: macroName, status: "Started")
        addMacroEvent(event)
    }
    
    /// Record macro step execution
    /// Requirements: 15.3 - Display current macro state and step
    func recordMacroStep(_ macroName: String, step: Int) {
        macroState.currentStep = step
        
        let event = DebugMacroEvent(macroName: macroName, status: "Step", step: step)
        addMacroEvent(event)
    }
    
    /// Record macro completion
    /// Requirements: 15.3 - Display current macro state and step
    func recordMacroCompleted(_ macroName: String) {
        macroState.isRunning = false
        macroState.currentMacroName = nil
        macroState.currentStep = nil
        macroState.totalSteps = nil
        
        let event = DebugMacroEvent(macroName: macroName, status: "Completed")
        addMacroEvent(event)
    }
    
    /// Record macro interruption
    /// Requirements: 15.3 - Display current macro state and step
    func recordMacroInterrupted(_ macroName: String) {
        macroState.isRunning = false
        macroState.currentMacroName = nil
        macroState.currentStep = nil
        macroState.totalSteps = nil
        
        let event = DebugMacroEvent(macroName: macroName, status: "Interrupted")
        addMacroEvent(event)
    }
    
    /// Update running instances from MacroScheduler
    /// Requirements: 1.6 - Display all running macro instances with their states
    func updateRunningInstances(_ instances: [MacroInstance]) {
        runningInstances = instances.map { RunningMacroInstanceState(from: $0) }
        macroState.isRunning = !instances.isEmpty
    }
    
    /// Record a direction event
    /// Requirements: 8.1, 8.4 - Display direction name and log direction events
    func recordDirectionEvent(_ event: DirectionEvent) {
        // Update direction state
        switch event.stick {
        case .left:
            if event.state == .pressed {
                leftStickDirectionState.activeDirection = event.direction
            } else if event.state == .released {
                if leftStickDirectionState.activeDirection == event.direction {
                    leftStickDirectionState.activeDirection = nil
                }
            }
            leftStickDirectionState.angle = event.angle
            leftStickDirectionState.magnitude = event.magnitude
        case .right:
            if event.state == .pressed {
                rightStickDirectionState.activeDirection = event.direction
            } else if event.state == .released {
                if rightStickDirectionState.activeDirection == event.direction {
                    rightStickDirectionState.activeDirection = nil
                }
            }
            rightStickDirectionState.angle = event.angle
            rightStickDirectionState.magnitude = event.magnitude
        }
        
        // Log the direction event
        let debugEvent = DebugInputEvent(direction: event)
        addDirectionEvent(debugEvent)
        addInputEvent(debugEvent)
    }
    
    /// Update stick position without direction change
    /// Requirements: 8.2, 8.3 - Display angle and magnitude
    func updateStickPosition(stick: StickType, angle: Double, magnitude: Double) {
        switch stick {
        case .left:
            leftStickDirectionState.angle = angle
            leftStickDirectionState.magnitude = magnitude
        case .right:
            rightStickDirectionState.angle = angle
            rightStickDirectionState.magnitude = magnitude
        }
    }
    
    /// Record a direction mapping action
    /// Requirements: 8.4 - Log triggered actions for direction mappings
    func recordDirectionAction(_ action: Action, direction: StickDirection, stick: StickType) {
        let event = DebugActionEvent(action: action, directionContext: "\(stick.rawValue) \(direction.rawValue)")
        addActionEvent(event)
    }
    
    // MARK: - Private Methods
    
    private func setupCallbacks() {
        // Button input callback - use addButtonInputHandler to support multiple handlers
        controllerManager.addButtonInputHandler(id: "DebugPanel") { [weak self] rawInput in
            Task { @MainActor in
                self?.recordButtonInput(rawInput.button, isPressed: rawInput.isPressed)
            }
        }
        
        // Axis input callback - use addAxisInputHandler to support multiple handlers
        controllerManager.addAxisInputHandler(id: "DebugPanel") { [weak self] rawInput in
            Task { @MainActor in
                guard let self = self else { return }
                let config = AxisConfig(deadzone: 0.1, sensitivity: 1.0, curve: .linear)
                let processed = self.inputProcessor.processAxisInput(rawInput, config: config)
                self.recordAxisInput(rawInput.axis, normalizedValue: processed.normalizedValue)
            }
        }
    }
    
    private func addInputEvent(_ event: DebugInputEvent) {
        inputEvents.append(event)
        if inputEvents.count > maxEventCount {
            inputEvents.removeFirst()
        }
    }
    
    private func addActionEvent(_ event: DebugActionEvent) {
        actionEvents.append(event)
        if actionEvents.count > maxEventCount {
            actionEvents.removeFirst()
        }
    }
    
    private func addMacroEvent(_ event: DebugMacroEvent) {
        macroEvents.append(event)
        if macroEvents.count > maxEventCount {
            macroEvents.removeFirst()
        }
    }
    
    private func addDirectionEvent(_ event: DebugInputEvent) {
        directionEvents.append(event)
        if directionEvents.count > maxEventCount {
            directionEvents.removeFirst()
        }
    }
}

#Preview {
    DebugPanelView()
}
