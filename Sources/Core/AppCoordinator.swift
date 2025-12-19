import Foundation

/// Central coordinator that wires all components together and manages the input pipeline
/// Requirements: 17.4 - Handle disconnection gracefully without crashing
///
/// Pipeline: ControllerManager → InputProcessor → MappingEngine → MacroScheduler/ScriptEngine → EventEmitter
public final class AppCoordinator {
    
    // MARK: - Core Components
    
    /// Controller manager for HID device handling
    public let controllerManager: ControllerManager
    
    /// Input processor for normalization and deadzone
    public let inputProcessor: InputProcessor
    
    /// Mapping engine for input-to-action conversion
    public let mappingEngine: MappingEngine
    
    /// Macro scheduler for macro execution
    public let macroScheduler: MacroScheduler
    
    /// Script engine for script execution
    public let scriptEngine: ScriptEngine
    
    /// Event emitter for keyboard/mouse output
    public let eventEmitter: EventEmitter
    
    /// Profile manager for configuration persistence
    public let profileManager: ProfileManager
    
    /// Permission manager for system permissions
    public let permissionManager: PermissionManager
    
    /// Application profile switcher for automatic profile switching
    public let applicationProfileSwitcher: ApplicationProfileSwitcher
    
    // MARK: - State
    
    /// Whether the coordinator is currently running
    public private(set) var isRunning: Bool = false
    
    /// Default axis configuration for processing
    private var defaultAxisConfig: AxisConfig
    
    /// Per-axis configurations (overrides default)
    private var axisConfigs: [AxisType: AxisConfig] = [:]
    
    /// Callback for debug panel - input events
    public var onInputEvent: ((InputEventInfo) -> Void)?
    
    /// Callback for debug panel - action execution
    public var onActionExecuted: ((Action) -> Void)?
    
    /// Callback for debug panel - macro state
    public var onMacroStateChanged: ((MacroStateInfo) -> Void)?
    
    // MARK: - Hold Detection State
    
    /// Track button press timestamps for hold detection
    private var buttonPressTimestamps: [ButtonType: Date] = [:]
    
    /// Track hold timers for each button
    private var holdTimers: [ButtonType: Timer] = [:]
    
    /// Track which hold mappings have been triggered (to avoid re-triggering)
    private var triggeredHoldMappings: [ButtonType: Set<UUID>] = [:]
    
    // MARK: - Initialization
    
    public init() {
        // Initialize all components
        self.controllerManager = ControllerManager()
        self.inputProcessor = InputProcessor()
        self.eventEmitter = EventEmitter()
        self.macroScheduler = MacroScheduler(eventEmitter: eventEmitter)
        self.scriptEngine = ScriptEngine()
        self.profileManager = ProfileManager()
        self.permissionManager = PermissionManager.shared
        self.mappingEngine = MappingEngine()
        self.applicationProfileSwitcher = ApplicationProfileSwitcher(profileManager: profileManager)
        
        // Default axis configuration
        self.defaultAxisConfig = AxisConfig(deadzone: 0.1, sensitivity: 1.0, curve: .linear)
        
        // Wire components together
        setupPipeline()
    }

    
    // MARK: - Pipeline Setup
    
    /// Wire all components together
    private func setupPipeline() {
        // Connect ControllerManager → InputProcessor → MappingEngine
        setupControllerCallbacks()
        
        // Connect ProfileManager → MappingEngine
        setupProfileCallbacks()
        
        // Connect MacroScheduler callbacks for debug panel
        setupMacroCallbacks()
    }
    
    /// Set up controller manager callbacks
    private func setupControllerCallbacks() {
        NSLog("[DEBUG] AppCoordinator: 🔧 Setting up controller callbacks...")
        
        // Handle controller connection
        controllerManager.onControllerConnected = { [weak self] controller in
            self?.handleControllerConnected(controller)
        }
        
        // Handle controller disconnection
        // Requirements: 17.4 - Handle disconnection gracefully
        controllerManager.onControllerDisconnected = { [weak self] controller in
            self?.handleControllerDisconnected(controller)
        }
        
        // Handle controller reconnection (for profile restoration)
        // Requirements: 1.6 - Restore active profile mappings on reconnection
        controllerManager.onControllerReconnected = { [weak self] controller in
            self?.handleControllerReconnected(controller)
        }
        
        // Handle button input - use addButtonInputHandler to support multiple handlers
        // This is the primary handler for input processing pipeline
        controllerManager.addButtonInputHandler(id: "AppCoordinator") { [unowned self] rawInput in
            NSLog("[DEBUG] AppCoordinator: 🔔 Button input handler triggered!")
            self.processButtonInput(rawInput)
        }
        
        // Handle axis input
        controllerManager.addAxisInputHandler(id: "AppCoordinator") { [unowned self] rawInput in
            self.processAxisInput(rawInput)
        }
        
        NSLog("[DEBUG] AppCoordinator: ✅ Controller callbacks set up")
    }
    
    /// Set up profile manager callbacks
    private func setupProfileCallbacks() {
        // Deactivate mappings when profile changes
        // Requirements: 13.3 - Deactivate all current mappings before activating new ones
        profileManager.onProfileWillChange = { [weak self] _ in
            self?.deactivateCurrentMappings()
        }
        
        // Activate new profile mappings
        profileManager.onProfileDidChange = { [weak self] profile in
            self?.activateProfile(profile)
        }
    }
    
    /// Set up macro scheduler callbacks
    private func setupMacroCallbacks() {
        macroScheduler.onStepExecuted = { [weak self] index, step in
            let info = MacroStateInfo(isRunning: true, currentStep: index, stepDescription: step.description)
            self?.onMacroStateChanged?(info)
        }
        
        macroScheduler.onMacroCompleted = { [weak self] in
            let info = MacroStateInfo(isRunning: false, currentStep: nil, stepDescription: nil)
            self?.onMacroStateChanged?(info)
        }
        
        // Connect button state provider for whileCondition macros
        // Requirements: 4.5 - Query current controller button state
        macroScheduler.buttonStateProvider = { [weak self] buttonName in
            self?.isButtonPressed(buttonName) ?? false
        }
    }
    
    // MARK: - Lifecycle
    
    /// Start the coordinator and begin processing inputs
    public func start() {
        guard !isRunning else { return }
        
        print("[DEBUG] AppCoordinator: 🚀 Starting...")
        isRunning = true
        
        // Load profiles
        do {
            try profileManager.refreshProfiles()
            print("[DEBUG] AppCoordinator: 📋 Loaded \(profileManager.profiles.count) profiles")
            
            // Activate first profile if available
            if let firstProfile = profileManager.profiles.first {
                print("[DEBUG] AppCoordinator: 📋 Setting active profile: \(firstProfile.name)")
                profileManager.setActiveProfile(firstProfile)
            } else {
                print("[DEBUG] AppCoordinator: ⚠️ No profiles found!")
            }
        } catch {
            print("[DEBUG] AppCoordinator: ❌ Failed to load profiles: \(error)")
        }
        
        // Check permission status
        print("[DEBUG] AppCoordinator: 🔐 Permission canEmitEvents: \(permissionManager.canEmitEvents)")
        print("[DEBUG] AppCoordinator: 🔐 Accessibility status: \(permissionManager.accessibilityStatus)")
        
        // Start controller discovery
        print("[DEBUG] AppCoordinator: 🎮 Starting controller discovery...")
        controllerManager.startDiscovery()
        
        // Start application profile switching if enabled
        applicationProfileSwitcher.loadBindingsFromAllProfiles()
        applicationProfileSwitcher.startMonitoring()
        
        print("[DEBUG] AppCoordinator: ✅ Started successfully")
    }
    
    /// Stop the coordinator and cleanup
    public func stop() {
        guard isRunning else { return }
        
        isRunning = false
        
        // Stop application profile switching
        applicationProfileSwitcher.stopMonitoring()
        
        // Stop controller discovery
        controllerManager.stopDiscovery()
        
        // Interrupt all running macros
        // Requirements: 1.5 - Stop all running macro instances
        macroScheduler.interruptAll()
        
        // Deactivate mappings
        deactivateCurrentMappings()
    }

    
    // MARK: - Controller Event Handling
    
    /// Handle controller connection
    private func handleControllerConnected(_ controller: Controller) {
        print("Controller connected: \(controller.name) via \(controller.connectionType)")
    }
    
    /// Handle controller disconnection gracefully
    /// Requirements: 17.4 - Handle disconnection without crashing
    /// Requirements: 1.5 - Stop all running macro instances
    private func handleControllerDisconnected(_ controller: Controller) {
        print("Controller disconnected: \(controller.name)")
        
        // Interrupt all running macros to prevent orphaned key presses
        macroScheduler.interruptAll()
    }
    
    /// Handle controller reconnection
    /// Requirements: 1.6 - Restore active profile mappings automatically
    private func handleControllerReconnected(_ controller: Controller) {
        print("Controller reconnected: \(controller.name)")
        
        // Profile is already active, mappings will work automatically
        // Just log for debugging
    }
    
    // MARK: - Input Processing Pipeline
    
    /// Process raw button input through the pipeline
    private func processButtonInput(_ rawInput: RawButtonInput) {
        NSLog("[DEBUG] AppCoordinator: 📥 Button input received: %@, pressed: %@", rawInput.button.rawValue, rawInput.isPressed ? "true" : "false")
        
        // Check if we can emit events
        guard permissionManager.canEmitEvents else {
            NSLog("[DEBUG] AppCoordinator: ⚠️ Cannot emit events - accessibility permission denied! Status: %@", String(describing: permissionManager.accessibilityStatus))
            return
        }
        
        // Step 1: Process through InputProcessor
        let buttonEvent = inputProcessor.processButtonInput(rawInput)
        NSLog("[DEBUG] AppCoordinator: 🔄 Button event processed: %@, state: %@", buttonEvent.button.rawValue, String(describing: buttonEvent.state))
        
        // Notify debug panel
        onInputEvent?(.button(buttonEvent))
        
        // Check if profile is active
        if let profile = mappingEngine.activeProfile {
            NSLog("[DEBUG] AppCoordinator: 📋 Active profile: %@, mappings count: %d", profile.name, profile.mappings.count)
            
            // Log button mappings for this specific button
            let buttonMappings = profile.mappings.filter { mapping in
                if case .button(let buttonType) = mapping.input {
                    return buttonType == rawInput.button
                }
                return false
            }
            NSLog("[DEBUG] AppCoordinator: 📋 Mappings for %@: %d", rawInput.button.rawValue, buttonMappings.count)
            for mapping in buttonMappings {
                NSLog("[DEBUG] AppCoordinator: 📋   -> trigger: %@, action: %@", String(describing: mapping.trigger), String(describing: mapping.action))
            }
        } else {
            NSLog("[DEBUG] AppCoordinator: ⚠️ No active profile!")
        }
        
        // Handle hold detection for button press/release
        if rawInput.isPressed {
            handleButtonPressed(rawInput.button)
        } else {
            handleButtonReleased(rawInput.button)
        }
        
        // Step 2: Get action results from MappingEngine (for press/release triggers)
        let actionResults = mappingEngine.handleButtonEvent(buttonEvent)
        NSLog("[DEBUG] AppCoordinator: 🎯 Actions from mapping engine: %d", actionResults.count)
        
        // Step 3: Execute each action
        for result in actionResults {
            NSLog("[DEBUG] AppCoordinator: ▶️ Executing action: %@, isToggleHold: %@", String(describing: result.action), result.isToggleHold ? "true" : "false")
            executeAction(result.action, triggerMode: getTriggerMode(for: buttonEvent), useHoldMode: result.isToggleHold)
        }
    }
    
    // MARK: - Hold Detection
    
    /// Handle button press - start hold detection timers
    private func handleButtonPressed(_ button: ButtonType) {
        // Record press timestamp
        buttonPressTimestamps[button] = Date()
        
        // Clear any previously triggered hold mappings for this button
        triggeredHoldMappings[button] = []
        
        // Cancel any existing timer for this button
        holdTimers[button]?.invalidate()
        holdTimers[button] = nil
        
        // Find hold mappings for this button
        guard let profile = mappingEngine.activeProfile else { return }
        
        let holdMappings = profile.mappings.filter { mapping in
            guard case .button(let buttonType) = mapping.input,
                  buttonType == button,
                  case .hold = mapping.trigger else {
                return false
            }
            return true
        }
        
        guard !holdMappings.isEmpty else { return }
        
        // Find the minimum hold threshold to start checking
        let minThreshold = holdMappings.compactMap { mapping -> TimeInterval? in
            if case .hold(let threshold) = mapping.trigger {
                return threshold
            }
            return nil
        }.min() ?? 0.5
        
        NSLog("[DEBUG] AppCoordinator: ⏱️ Starting hold timer for %@ with min threshold %.2fs", button.rawValue, minThreshold)
        
        // Start a timer to check for hold triggers
        // Use a repeating timer to check multiple thresholds
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            self?.checkHoldTriggers(for: button)
        }
        holdTimers[button] = timer
        
        // Also schedule on the main run loop to ensure it fires
        RunLoop.main.add(timer, forMode: .common)
    }
    
    /// Handle button release - cancel hold detection timers
    private func handleButtonReleased(_ button: ButtonType) {
        // Cancel hold timer
        holdTimers[button]?.invalidate()
        holdTimers[button] = nil
        
        // Clear press timestamp
        buttonPressTimestamps.removeValue(forKey: button)
        
        // Clear triggered hold mappings
        triggeredHoldMappings.removeValue(forKey: button)
        
        NSLog("[DEBUG] AppCoordinator: ⏱️ Cancelled hold timer for %@", button.rawValue)
    }
    
    /// Check if any hold triggers should fire
    private func checkHoldTriggers(for button: ButtonType) {
        guard let pressTime = buttonPressTimestamps[button],
              let profile = mappingEngine.activeProfile else {
            // Button was released or no profile, cancel timer
            holdTimers[button]?.invalidate()
            holdTimers[button] = nil
            return
        }
        
        let holdDuration = Date().timeIntervalSince(pressTime)
        
        // Find hold mappings that should trigger
        let holdMappings = profile.mappings.filter { mapping in
            guard case .button(let buttonType) = mapping.input,
                  buttonType == button,
                  case .hold(let threshold) = mapping.trigger else {
                return false
            }
            
            // Check if this mapping should trigger
            // Only trigger if duration >= threshold and not already triggered
            let alreadyTriggered = triggeredHoldMappings[button]?.contains(mapping.id) ?? false
            return holdDuration >= threshold && !alreadyTriggered
        }
        
        // Execute actions for triggered hold mappings
        for mapping in holdMappings {
            NSLog("[DEBUG] AppCoordinator: ⏱️ Hold trigger fired for %@ after %.2fs", button.rawValue, holdDuration)
            
            // Mark as triggered
            if triggeredHoldMappings[button] == nil {
                triggeredHoldMappings[button] = []
            }
            triggeredHoldMappings[button]?.insert(mapping.id)
            
            // Execute the action
            executeAction(mapping.action, triggerMode: mapping.trigger)
        }
    }
    
    /// Process raw axis input through the pipeline
    private func processAxisInput(_ rawInput: RawAxisInput) {
        // Only log significant axis changes to avoid spam
        if abs(rawInput.rawValue) > 10 {
            print("[DEBUG] 📥 Axis input: \(rawInput.axis), raw: \(rawInput.rawValue)")
        }
        
        // Check if we can emit events
        guard permissionManager.canEmitEvents else {
            // Only log once per axis to avoid spam
            print("[DEBUG] ⚠️ Cannot emit events - permission denied!")
            return
        }
        
        // Get axis-specific config or use default
        let config = axisConfigs[rawInput.axis] ?? defaultAxisConfig
        
        // Step 1: Process through InputProcessor
        let axisEvent = inputProcessor.processAxisInput(rawInput, config: config)
        
        // Notify debug panel
        onInputEvent?(.axis(axisEvent))
        
        // Step 2: Get actions from MappingEngine
        let actions = mappingEngine.handleAxisEvent(axisEvent)
        
        // Log if we got actions
        if !actions.isEmpty {
            print("[DEBUG] 🎯 Axis actions: \(actions.count) for \(rawInput.axis)")
        }
        
        // Step 3: Execute each action
        for action in actions {
            print("[DEBUG] ▶️ Executing axis action: \(action)")
            executeAction(action, triggerMode: .press)
        }
    }
    
    /// Get trigger mode from button event
    private func getTriggerMode(for event: ButtonEvent) -> TriggerMode {
        switch event.state {
        case .pressed:
            return .press
        case .released:
            return .release
        case .held(let duration):
            return .hold(threshold: duration)
        }
    }
    
    // MARK: - Action Execution
    
    /// Execute a single action
    /// - Parameters:
    ///   - action: The action to execute
    ///   - triggerMode: The trigger mode that caused this action
    ///   - useHoldMode: If true, use continuous key holding (for toggle mode)
    private func executeAction(_ action: Action, triggerMode: TriggerMode, useHoldMode: Bool = false) {
        // Notify debug panel
        onActionExecuted?(action)
        
        switch action {
        case .keyPress(let keyAction):
            if useHoldMode {
                // For toggle mode, use continuous key holding
                eventEmitter.startHoldingKey(keyAction.keyCode, modifiers: keyAction.modifiers)
            } else {
                eventEmitter.emitKeyDown(keyAction.keyCode, modifiers: keyAction.modifiers)
            }
            
        case .keyRelease(let keyAction):
            // Stop holding if it was being held
            eventEmitter.stopHoldingKey(keyAction.keyCode)
            eventEmitter.emitKeyUp(keyAction.keyCode, modifiers: keyAction.modifiers)
            
        case .mouseButton(let mouseAction):
            eventEmitter.emitMouseClick(mouseAction.button)
            
        case .mouseMove:
            // Mouse move is typically handled continuously from axis events
            // The actual movement delta comes from the axis value
            break
            
        case .mouseScroll(let scrollAction):
            let amount = scrollAction.amount
            switch scrollAction.direction {
            case .up:
                eventEmitter.emitMouseScroll(dx: 0, dy: amount)
            case .down:
                eventEmitter.emitMouseScroll(dx: 0, dy: -amount)
            case .left:
                eventEmitter.emitMouseScroll(dx: -amount, dy: 0)
            case .right:
                eventEmitter.emitMouseScroll(dx: amount, dy: 0)
            }
            
        case .macro(let macro):
            macroScheduler.execute(macro, trigger: triggerMode)
            
        case .script(let script):
            executeScript(script)
        }
    }
    
    /// Execute a script asynchronously
    private func executeScript(_ script: Script) {
        let context = DefaultScriptContext(
            eventEmitter: eventEmitter,
            buttonStateProvider: { [weak self] buttonName in
                self?.isButtonPressed(buttonName) ?? false
            }
        )
        
        Task {
            do {
                try await scriptEngine.execute(script, context: context)
            } catch {
                print("Script execution error: \(error)")
            }
        }
    }
    
    /// Check if a button is currently pressed (for script API)
    private func isButtonPressed(_ buttonName: String) -> Bool {
        guard let buttonType = ButtonType(rawValue: buttonName) else {
            return false
        }
        return controllerManager.isButtonPressed(buttonType)
    }

    
    // MARK: - Profile Management
    
    /// Deactivate current mappings
    private func deactivateCurrentMappings() {
        // Reset mapping engine state
        mappingEngine.resetToggleStates()
        mappingEngine.clearAxisToKeyConfigs()
        
        // Interrupt all running macros
        // Requirements: 1.5 - Stop all running macro instances
        macroScheduler.interruptAll()
    }
    
    /// Activate a profile's mappings
    private func activateProfile(_ profile: Profile?) {
        guard let profile = profile else {
            print("[DEBUG] AppCoordinator: ⚠️ Deactivating profile (nil)")
            mappingEngine.activeProfile = nil
            return
        }
        
        print("[DEBUG] AppCoordinator: 📋 Activating profile: \(profile.name)")
        print("[DEBUG] AppCoordinator: 📋 Profile has \(profile.mappings.count) mappings")
        
        // Log each mapping for debugging
        for (index, mapping) in profile.mappings.enumerated() {
            print("[DEBUG] AppCoordinator: 📋 Mapping[\(index)]: input=\(mapping.input), trigger=\(mapping.trigger), action=\(mapping.action)")
        }
        
        // Set the profile on the mapping engine
        mappingEngine.activeProfile = profile
        
        // Configure axis-to-key mappings from profile
        configureAxisToKeyMappings(from: profile)
        
        // Update axis configs from profile mappings
        updateAxisConfigs(from: profile)
    }
    
    /// Configure axis-to-key mappings from profile
    private func configureAxisToKeyMappings(from profile: Profile) {
        // Clear existing configs
        mappingEngine.clearAxisToKeyConfigs()
        
        // Group axis mappings by axis type
        var axisKeyMappings: [AxisType: (positive: KeyAction?, negative: KeyAction?, threshold: Double)] = [:]
        
        for mapping in profile.mappings {
            guard case .axis(let axisType) = mapping.input else { continue }
            
            // Check if this is a key action
            if case .keyPress(let keyAction) = mapping.action {
                var current = axisKeyMappings[axisType] ?? (nil, nil, 0.5)
                
                // Determine if this is positive or negative direction based on trigger
                // For simplicity, we'll use the first key mapping as positive
                if current.positive == nil {
                    current.positive = keyAction
                } else if current.negative == nil {
                    current.negative = keyAction
                }
                
                axisKeyMappings[axisType] = current
            }
        }
        
        // Apply axis-to-key configs
        for (axis, config) in axisKeyMappings {
            let axisToKeyConfig = AxisToKeyConfig(
                positiveKey: config.positive,
                negativeKey: config.negative,
                threshold: config.threshold
            )
            mappingEngine.setAxisToKeyConfig(axisToKeyConfig, for: axis)
        }
    }
    
    /// Update axis configurations from profile
    private func updateAxisConfigs(from profile: Profile) {
        axisConfigs.removeAll()
        
        for mapping in profile.mappings {
            guard case .axis(let axisType) = mapping.input else { continue }
            
            // Check for mouse move action which contains axis config
            if case .mouseMove(let moveAction) = mapping.action {
                let config = AxisConfig(
                    deadzone: moveAction.deadzone,
                    sensitivity: moveAction.sensitivity,
                    curve: moveAction.curve
                )
                axisConfigs[axisType] = config
            }
        }
    }
    
    // MARK: - Configuration
    
    /// Set the default axis configuration
    public func setDefaultAxisConfig(_ config: AxisConfig) {
        self.defaultAxisConfig = config
    }
    
    /// Set axis configuration for a specific axis
    public func setAxisConfig(_ config: AxisConfig, for axis: AxisType) {
        axisConfigs[axis] = config
    }
    
    /// Get axis configuration for a specific axis
    public func getAxisConfig(for axis: AxisType) -> AxisConfig {
        return axisConfigs[axis] ?? defaultAxisConfig
    }
    
    // MARK: - Macro Control
    
    /// Interrupt the currently running macro (legacy - interrupts all)
    public func interruptMacro() {
        macroScheduler.interruptAll()
    }
    
    /// Interrupt a specific macro instance by ID
    /// Requirements: 1.4 - Stop only that macro instance and release its pressed keys
    public func interruptMacro(instanceId: UUID) {
        macroScheduler.interrupt(instanceId: instanceId)
    }
    
    /// Interrupt all running macros
    /// Requirements: 1.5 - Stop all running macro instances and release all pressed keys
    public func interruptAllMacros() {
        macroScheduler.interruptAll()
    }
    
    /// Check if a macro is currently running
    public var isMacroRunning: Bool {
        return macroScheduler.isRunning
    }
    
    /// Get all currently running macro instances
    /// Requirements: 1.6 - Return list of all currently executing macro instances with their states
    public var runningMacroInstances: [MacroInstance] {
        return macroScheduler.runningInstances
    }
    
    /// Execute a macro and return the instance ID for tracking
    /// Requirements: 1.1 - Create new execution instance and run concurrently
    @discardableResult
    public func executeMacro(_ macro: Macro, trigger: TriggerMode) -> UUID? {
        return macroScheduler.execute(macro, trigger: trigger)
    }
}

// MARK: - Supporting Types

/// Information about an input event for debug panel
public enum InputEventInfo {
    case button(ButtonEvent)
    case axis(AxisEvent)
}

/// Information about macro state for debug panel
public struct MacroStateInfo {
    public let isRunning: Bool
    public let currentStep: Int?
    public let stepDescription: String?
    
    public init(isRunning: Bool, currentStep: Int?, stepDescription: String?) {
        self.isRunning = isRunning
        self.currentStep = currentStep
        self.stepDescription = stepDescription
    }
}

// MARK: - MacroStep Description Extension

extension MacroStep {
    /// Human-readable description of the macro step
    var description: String {
        switch self {
        case .keyDown(let keyCode):
            return "Key Down: \(keyCode)"
        case .keyUp(let keyCode):
            return "Key Up: \(keyCode)"
        case .mouseClick(let button):
            return "Mouse Click: \(button)"
        case .mouseMove(let dx, let dy):
            return "Mouse Move: (\(dx), \(dy))"
        case .delay(let ms):
            return "Delay: \(ms)ms"
        }
    }
}
