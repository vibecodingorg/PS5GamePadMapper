import Foundation

/// Protocol for macro execution scheduling
/// Requirements: 8.1, 8.4, 9.1, 9.3, 10.1, 10.2, 11.1, 11.2, 1.1-1.6 (parallel execution)
public protocol MacroSchedulerProtocol {
    /// Whether any macro is currently running
    var isRunning: Bool { get }
    
    /// The current step index being executed (nil if not running)
    /// For parallel execution, returns the step of the first running instance
    var currentStep: Int? { get }
    
    /// All currently running macro instances
    /// Requirements: 1.6 - Return list of executing macro instances with their states
    var runningInstances: [MacroInstance] { get }
    
    /// Execute a macro with the specified trigger mode
    /// Returns the instance ID for parallel execution tracking
    /// Requirements: 1.1 - Create new execution instance and run concurrently
    @discardableResult
    func execute(_ macro: Macro, trigger: TriggerMode) -> UUID?
    
    /// Stop a specific macro instance gracefully
    /// Requirements: 1.4 - Stop only that macro instance
    func stop(instanceId: UUID)
    
    /// Stop the current macro execution gracefully (legacy support)
    func stop()
    
    /// Interrupt a specific macro instance and release its keys
    /// Requirements: 1.4 - Release only its pressed keys
    func interrupt(instanceId: UUID)
    
    /// Interrupt all running macros immediately and release all keys
    /// Requirements: 1.5 - Stop all running macro instances
    func interruptAll()
    
    /// Interrupt the current macro immediately (legacy support, calls interruptAll)
    func interrupt()
}
