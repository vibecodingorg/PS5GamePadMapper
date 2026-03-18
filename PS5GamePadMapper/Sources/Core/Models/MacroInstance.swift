import Foundation

/// A running macro instance with its own independent state
/// Requirements: 1.2 - Maintain independent state for each macro instance
public final class MacroInstance: Identifiable {
    
    // MARK: - Properties
    
    /// Unique identifier for this instance
    public let id: UUID
    
    /// The macro being executed
    public let macro: Macro
    
    /// Current step index being executed
    public private(set) var currentStep: Int
    
    /// Keys currently pressed by this macro instance
    public private(set) var pressedKeys: Set<UInt16>
    
    /// Whether this instance is currently running
    public private(set) var isRunning: Bool
    
    /// Current loop iteration count (for loop/whileCondition macros)
    public private(set) var loopCount: Int
    
    /// Flag to signal interruption for this instance
    public var isInterrupted: Bool
    
    /// Flag to signal stop request for this instance
    public var shouldStop: Bool
    
    /// Condition evaluator for whileCondition macros
    public var conditionEvaluator: (() -> Bool)?
    
    /// Toggle state for toggle macros
    public var toggleActive: Bool
    
    // MARK: - Initialization
    
    public init(macro: Macro, conditionEvaluator: (() -> Bool)? = nil) {
        self.id = UUID()
        self.macro = macro
        self.currentStep = 0
        self.pressedKeys = []
        self.isRunning = true
        self.loopCount = 0
        self.isInterrupted = false
        self.shouldStop = false
        self.conditionEvaluator = conditionEvaluator
        self.toggleActive = false
    }
    
    // MARK: - State Management
    
    /// Update the current step index
    public func setCurrentStep(_ step: Int) {
        currentStep = step
    }
    
    /// Add a pressed key
    public func addPressedKey(_ keyCode: UInt16) {
        pressedKeys.insert(keyCode)
    }
    
    /// Remove a pressed key
    public func removePressedKey(_ keyCode: UInt16) {
        pressedKeys.remove(keyCode)
    }
    
    /// Clear all pressed keys
    public func clearPressedKeys() {
        pressedKeys.removeAll()
    }
    
    /// Increment loop count
    public func incrementLoopCount() {
        loopCount += 1
    }
    
    /// Mark instance as stopped
    public func markStopped() {
        isRunning = false
    }
    
    /// Mark instance as running
    public func markRunning() {
        isRunning = true
    }
}

// MARK: - MacroInstanceState

/// Snapshot of a macro instance's state for querying
/// Requirements: 1.6 - Return list of executing macro instances with their states
public struct MacroInstanceState: Equatable {
    public let instanceId: UUID
    public let macroId: UUID
    public let macroName: String
    public let currentStep: Int
    public let totalSteps: Int
    public let isRunning: Bool
    public let loopCount: Int
    public let pressedKeys: Set<UInt16>
    
    public init(from instance: MacroInstance) {
        self.instanceId = instance.id
        self.macroId = instance.macro.id
        self.macroName = instance.macro.name
        self.currentStep = instance.currentStep
        self.totalSteps = instance.macro.steps.count
        self.isRunning = instance.isRunning
        self.loopCount = instance.loopCount
        self.pressedKeys = instance.pressedKeys
    }
}
