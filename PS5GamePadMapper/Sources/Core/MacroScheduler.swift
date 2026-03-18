import Foundation

/// Script context for macro condition evaluation
/// Requirements: 4.5 - Query current controller button state
final class MacroScriptContext: ScriptContext {
    private let buttonStateProvider: ((String) -> Bool)?
    
    init(buttonStateProvider: ((String) -> Bool)?) {
        self.buttonStateProvider = buttonStateProvider
    }
    
    func pressKey(_ key: String) {}
    func releaseKey(_ key: String) {}
    func tapKey(_ key: String, duration: Int) {}
    func mouseClick(_ button: String) {}
    func mouseMove(dx: Int, dy: Int) {}
    func sleep(_ milliseconds: Int) async {}
    
    func isButtonPressed(_ button: String) -> Bool {
        return buttonStateProvider?(button) ?? false
    }
}

/// Macro scheduler that executes macros with proper timing and state management
/// Supports parallel execution of multiple macros
/// Requirements: 8.1, 8.4, 9.1, 9.2, 9.3, 9.4, 10.1, 10.2, 10.3, 10.4, 11.1, 11.2, 11.3
/// Requirements: 1.1-1.6 (parallel execution)
public final class MacroScheduler: MacroSchedulerProtocol {
    
    // MARK: - Properties
    
    /// The event emitter used to emit keyboard/mouse events
    private let eventEmitter: EventEmitterProtocol
    
    /// All currently running macro instances
    /// Requirements: 1.2 - Maintain independent state for each macro instance
    private var instances: [UUID: MacroInstance] = [:]
    
    /// Lock for thread-safe access to instances
    private let instancesLock = NSLock()
    
    /// Execution queue for macro steps
    private let executionQueue = DispatchQueue(label: "com.ps5gamepadmapper.macroscheduler", qos: .userInteractive, attributes: .concurrent)
    
    /// Callback for step execution (for testing)
    public var onStepExecuted: ((Int, MacroStep) -> Void)? = nil
    
    /// Callback for macro completion (for testing)
    public var onMacroCompleted: (() -> Void)? = nil
    
    /// Recorded executed steps (for testing)
    public private(set) var executedSteps: [(index: Int, step: MacroStep)] = []
    
    /// Whether to record executed steps (for testing)
    public var recordSteps: Bool = false
    
    /// Button state provider for whileCondition macros
    public var buttonStateProvider: ((String) -> Bool)?
    
    // MARK: - MacroSchedulerProtocol Properties
    
    /// Whether any macro is currently running
    public var isRunning: Bool {
        instancesLock.lock()
        defer { instancesLock.unlock() }
        return !instances.isEmpty
    }
    
    /// The current step index of the first running instance
    public var currentStep: Int? {
        instancesLock.lock()
        defer { instancesLock.unlock() }
        return instances.values.first?.currentStep
    }
    
    /// All currently running macro instances
    /// Requirements: 1.6 - Return list of executing macro instances with their states
    public var runningInstances: [MacroInstance] {
        instancesLock.lock()
        defer { instancesLock.unlock() }
        return Array(instances.values)
    }
    
    // MARK: - Initialization
    
    public init(eventEmitter: EventEmitterProtocol) {
        self.eventEmitter = eventEmitter
    }
    
    // MARK: - MacroSchedulerProtocol Methods
    
    /// Execute a macro with the specified trigger mode
    /// Requirements: 1.1 - Create new execution instance and run concurrently
    @discardableResult
    public func execute(_ macro: Macro, trigger: TriggerMode) -> UUID? {
        // Handle toggle macro specially
        if macro.type == .toggle {
            return handleToggleTrigger(macro)
        }
        
        let instance = MacroInstance(macro: macro)
        
        // Set up condition evaluator for whileCondition macros
        if case .whileCondition(let condition) = macro.type {
            instance.conditionEvaluator = { [weak self] in
                self?.evaluateCondition(condition) ?? false
            }
        }
        
        instancesLock.lock()
        instances[instance.id] = instance
        instancesLock.unlock()
        
        executionQueue.async { [weak self] in
            self?.executeInstance(instance)
        }
        
        return instance.id
    }
    
    /// Stop a specific macro instance gracefully
    /// Requirements: 1.4 - Stop only that macro instance
    public func stop(instanceId: UUID) {
        instancesLock.lock()
        instances[instanceId]?.shouldStop = true
        instancesLock.unlock()
    }
    
    /// Stop the first running macro (legacy support)
    public func stop() {
        instancesLock.lock()
        instances.values.first?.shouldStop = true
        instancesLock.unlock()
    }
    
    /// Interrupt a specific macro instance and release its keys
    /// Requirements: 1.4 - Release only its pressed keys
    public func interrupt(instanceId: UUID) {
        instancesLock.lock()
        guard let instance = instances[instanceId] else {
            instancesLock.unlock()
            return
        }
        instance.isInterrupted = true
        instancesLock.unlock()
        
        releaseKeysForInstance(instance)
        removeInstance(instanceId)
    }
    
    /// Interrupt all running macros immediately and release all keys
    /// Requirements: 1.5 - Stop all running macro instances
    public func interruptAll() {
        instancesLock.lock()
        let allInstances = Array(instances.values)
        for instance in allInstances {
            instance.isInterrupted = true
        }
        instancesLock.unlock()
        
        for instance in allInstances {
            releaseKeysForInstance(instance)
        }
        
        instancesLock.lock()
        instances.removeAll()
        instancesLock.unlock()
    }
    
    /// Interrupt all macros (legacy support)
    public func interrupt() {
        interruptAll()
    }
    
    // MARK: - Private Execution Methods
    
    private func executeInstance(_ instance: MacroInstance) {
        switch instance.macro.type {
        case .sequence:
            executeStepsOnce(instance)
            completeInstance(instance)
            
        case .loop(let interval, let maxCount):
            executeLoop(instance, interval: interval, maxCount: maxCount)
            
        case .toggle:
            executeToggleLoop(instance)
            
        case .whileCondition:
            executeWhileCondition(instance)
        }
    }
    
    /// Execute steps once in order
    private func executeStepsOnce(_ instance: MacroInstance) {
        for (index, step) in instance.macro.steps.enumerated() {
            if instance.isInterrupted || instance.shouldStop {
                break
            }
            
            instance.setCurrentStep(index)
            executeStep(step, instance: instance, at: index)
        }
    }
    
    /// Execute a single macro step
    private func executeStep(_ step: MacroStep, instance: MacroInstance, at index: Int) {
        switch step {
        case .keyDown(let keyCode):
            eventEmitter.emitKeyDown(keyCode, modifiers: [])
            instance.addPressedKey(keyCode)
            
        case .keyUp(let keyCode):
            eventEmitter.emitKeyUp(keyCode, modifiers: [])
            instance.removePressedKey(keyCode)
            
        case .mouseClick(let button):
            eventEmitter.emitMouseDown(button)
            eventEmitter.emitMouseUp(button)
            
        case .mouseMove(let dx, let dy):
            eventEmitter.emitMouseMove(dx: CGFloat(dx), dy: CGFloat(dy))
            
        case .delay(let milliseconds):
            Thread.sleep(forTimeInterval: Double(milliseconds) / 1000.0)
        }
        
        if recordSteps {
            executedSteps.append((index: index, step: step))
        }
        
        onStepExecuted?(index, step)
    }
    
    /// Execute loop macro (turbo)
    /// Requirements: 9.1, 9.2, 9.3, 9.4
    private func executeLoop(_ instance: MacroInstance, interval: Int, maxCount: Int) {
        while !instance.isInterrupted && !instance.shouldStop {
            if maxCount > 0 && instance.loopCount >= maxCount {
                break
            }
            
            executeStepsOnce(instance)
            
            if instance.isInterrupted || instance.shouldStop {
                break
            }
            
            instance.incrementLoopCount()
            Thread.sleep(forTimeInterval: Double(interval) / 1000.0)
        }
        
        completeInstance(instance)
    }
    
    /// Execute whileCondition macro
    /// Requirements: 4.2, 4.3, 4.4
    private func executeWhileCondition(_ instance: MacroInstance) {
        guard let evaluator = instance.conditionEvaluator else {
            completeInstance(instance)
            return
        }
        
        while !instance.isInterrupted && !instance.shouldStop && evaluator() {
            executeStepsOnce(instance)
            
            if instance.isInterrupted || instance.shouldStop {
                break
            }
            
            instance.incrementLoopCount()
        }
        
        completeInstance(instance)
    }
    
    /// Handle toggle macro trigger
    /// Requirements: 10.1, 10.2
    private func handleToggleTrigger(_ macro: Macro) -> UUID? {
        instancesLock.lock()
        
        // Find existing toggle instance for this macro
        let existingInstance = instances.values.first { 
            $0.macro.id == macro.id && $0.macro.type == .toggle 
        }
        
        if let existing = existingInstance, existing.toggleActive {
            // Second press - stop the macro
            existing.shouldStop = true
            existing.toggleActive = false
            instancesLock.unlock()
            return existing.id
        } else {
            instancesLock.unlock()
            
            // First press - start the macro
            let instance = MacroInstance(macro: macro)
            instance.toggleActive = true
            
            instancesLock.lock()
            instances[instance.id] = instance
            instancesLock.unlock()
            
            executionQueue.async { [weak self] in
                self?.executeToggleLoop(instance)
            }
            
            return instance.id
        }
    }
    
    /// Execute toggle macro loop
    /// Requirements: 10.1, 10.2, 10.3, 10.4
    private func executeToggleLoop(_ instance: MacroInstance) {
        while !instance.isInterrupted && !instance.shouldStop && instance.toggleActive {
            executeStepsOnce(instance)
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        completeInstance(instance)
    }
    
    /// Release all keys for a specific instance
    private func releaseKeysForInstance(_ instance: MacroInstance) {
        for keyCode in instance.pressedKeys {
            eventEmitter.emitKeyUp(keyCode, modifiers: [])
        }
        instance.clearPressedKeys()
    }
    
    /// Complete macro execution and remove instance
    private func completeInstance(_ instance: MacroInstance) {
        releaseKeysForInstance(instance)
        removeInstance(instance.id)
        onMacroCompleted?()
    }
    
    /// Remove instance from tracking
    private func removeInstance(_ instanceId: UUID) {
        instancesLock.lock()
        instances.removeValue(forKey: instanceId)
        instancesLock.unlock()
    }
    
    /// Evaluate a condition string for whileCondition macros
    /// Requirements: 4.2, 4.5 - Parse condition and evaluate with button state
    private func evaluateCondition(_ condition: String) -> Bool {
        let parser = ScriptParser()
        
        do {
            let conditionExpr = try parser.parseCondition(condition)
            let context = MacroScriptContext(buttonStateProvider: buttonStateProvider)
            let evaluator = ConditionEvaluator()
            return evaluator.evaluate(conditionExpr, context: context)
        } catch {
            // If parsing fails, return false to stop the macro
            return false
        }
    }
    
    // MARK: - Testing Support
    
    /// Get the current toggle state for a macro (for testing)
    public func isToggleActive(for macroId: UUID) -> Bool {
        instancesLock.lock()
        defer { instancesLock.unlock() }
        return instances.values.first { $0.macro.id == macroId }?.toggleActive ?? false
    }
    
    /// Get whether any toggle macro is active (for testing, legacy support)
    public var isToggleActive: Bool {
        instancesLock.lock()
        defer { instancesLock.unlock() }
        return instances.values.contains { $0.toggleActive }
    }
    
    /// Get the current loop count for an instance (for testing)
    public func loopCount(for instanceId: UUID) -> Int {
        instancesLock.lock()
        defer { instancesLock.unlock() }
        return instances[instanceId]?.loopCount ?? 0
    }
    
    /// Clear recorded steps (for testing)
    public func clearRecordedSteps() {
        executedSteps.removeAll()
    }
    
    /// Reset all state (for testing)
    public func resetAll() {
        interruptAll()
        executedSteps.removeAll()
    }
    
    /// Get pressed keys for an instance (for testing)
    public func pressedKeys(for instanceId: UUID) -> Set<UInt16> {
        instancesLock.lock()
        defer { instancesLock.unlock() }
        return instances[instanceId]?.pressedKeys ?? []
    }
    
    /// Get all pressed keys across all instances (for testing, legacy support)
    public var currentPressedKeys: Set<UInt16> {
        instancesLock.lock()
        defer { instancesLock.unlock() }
        var allKeys = Set<UInt16>()
        for instance in instances.values {
            allKeys.formUnion(instance.pressedKeys)
        }
        return allKeys
    }
    
    /// Execute macro synchronously for testing
    public func executeSynchronously(_ macro: Macro) {
        let instance = MacroInstance(macro: macro)
        
        if case .whileCondition(let condition) = macro.type {
            instance.conditionEvaluator = { [weak self] in
                self?.evaluateCondition(condition) ?? false
            }
        }
        
        instancesLock.lock()
        instances[instance.id] = instance
        instancesLock.unlock()
        
        switch macro.type {
        case .sequence:
            executeStepsOnce(instance)
            completeInstance(instance)
            
        case .loop(_, let maxCount):
            guard maxCount > 0 else {
                completeInstance(instance)
                return
            }
            
            for _ in 0..<maxCount {
                if instance.isInterrupted || instance.shouldStop { break }
                executeStepsOnce(instance)
                instance.incrementLoopCount()
            }
            completeInstance(instance)
            
        case .toggle:
            executeStepsOnce(instance)
            completeInstance(instance)
            
        case .whileCondition:
            guard let evaluator = instance.conditionEvaluator else {
                completeInstance(instance)
                return
            }
            
            var iterations = 0
            let maxIterations = 1000 // Safety limit
            while evaluator() && iterations < maxIterations {
                if instance.isInterrupted || instance.shouldStop { break }
                executeStepsOnce(instance)
                instance.incrementLoopCount()
                iterations += 1
            }
            completeInstance(instance)
        }
    }
}
