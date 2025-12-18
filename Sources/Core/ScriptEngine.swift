import Foundation
import Carbon.HIToolbox

/// Script execution engine that parses and executes scripts
/// Requirements: 12.1 - Execute scripts in dedicated execution context
public final class ScriptEngine: ScriptEngineProtocol {
    
    /// Errors that can occur during script execution
    public enum ScriptError: Error, Equatable {
        case syntaxError(line: Int, message: String)
        case unknownCommand(command: String)
        case invalidArgument(command: String, argument: String)
        case executionError(message: String)
    }
    
    /// Condition evaluator for if/while statements
    private let conditionEvaluator: ConditionEvaluator
    
    /// Script parser for AST-based execution
    private let scriptParser: ScriptParser
    
    public init() {
        self.conditionEvaluator = ConditionEvaluator()
        self.scriptParser = ScriptParser()
    }
    
    /// Execute a script in the given context
    /// Requirements: 12.1 - Execute scripts in dedicated execution context
    public func execute(_ script: Script, context: ScriptContext) async throws {
        let commands = try parse(script.source)
        
        for command in commands {
            try await executeCommand(command, context: context)
        }
    }
    
    // MARK: - Parsing
    
    /// Parsed command representation
    public enum Command: Equatable {
        case pressKey(key: String)
        case releaseKey(key: String)
        case tapKey(key: String, duration: Int)
        case mouseClick(button: String)
        case mouseMove(dx: Int, dy: Int)
        case sleep(milliseconds: Int)
        case isButtonPressed(button: String)  // For conditional logic
    }
    
    /// Parse script source into commands
    public func parse(_ source: String) throws -> [Command] {
        var commands: [Command] = []
        let lines = source.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
                continue
            }
            
            if let command = try parseCommand(trimmed, lineNumber: index + 1) {
                commands.append(command)
            }
        }
        
        return commands
    }

    
    /// Parse a single command line
    private func parseCommand(_ line: String, lineNumber: Int) throws -> Command? {
        // Match function call pattern: functionName(args)
        let pattern = #"^(\w+)\s*\((.*)\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) else {
            throw ScriptError.syntaxError(line: lineNumber, message: "Invalid syntax: \(line)")
        }
        
        guard let funcNameRange = Range(match.range(at: 1), in: line),
              let argsRange = Range(match.range(at: 2), in: line) else {
            throw ScriptError.syntaxError(line: lineNumber, message: "Could not parse function call")
        }
        
        let funcName = String(line[funcNameRange])
        let argsString = String(line[argsRange])
        let args = parseArguments(argsString)
        
        switch funcName {
        case "pressKey":
            guard args.count == 1 else {
                throw ScriptError.syntaxError(line: lineNumber, message: "pressKey requires 1 argument")
            }
            return .pressKey(key: args[0])
            
        case "releaseKey":
            guard args.count == 1 else {
                throw ScriptError.syntaxError(line: lineNumber, message: "releaseKey requires 1 argument")
            }
            return .releaseKey(key: args[0])
            
        case "tapKey":
            guard args.count == 2 else {
                throw ScriptError.syntaxError(line: lineNumber, message: "tapKey requires 2 arguments")
            }
            guard let duration = Int(args[1]) else {
                throw ScriptError.invalidArgument(command: "tapKey", argument: args[1])
            }
            return .tapKey(key: args[0], duration: duration)
            
        case "mouseClick":
            guard args.count == 1 else {
                throw ScriptError.syntaxError(line: lineNumber, message: "mouseClick requires 1 argument")
            }
            return .mouseClick(button: args[0])
            
        case "mouseMove":
            guard args.count == 2 else {
                throw ScriptError.syntaxError(line: lineNumber, message: "mouseMove requires 2 arguments")
            }
            guard let dx = Int(args[0]), let dy = Int(args[1]) else {
                throw ScriptError.invalidArgument(command: "mouseMove", argument: "\(args[0]), \(args[1])")
            }
            return .mouseMove(dx: dx, dy: dy)
            
        case "sleep":
            guard args.count == 1 else {
                throw ScriptError.syntaxError(line: lineNumber, message: "sleep requires 1 argument")
            }
            guard let ms = Int(args[0]) else {
                throw ScriptError.invalidArgument(command: "sleep", argument: args[0])
            }
            return .sleep(milliseconds: ms)
            
        case "isButtonPressed":
            guard args.count == 1 else {
                throw ScriptError.syntaxError(line: lineNumber, message: "isButtonPressed requires 1 argument")
            }
            return .isButtonPressed(button: args[0])
            
        default:
            throw ScriptError.unknownCommand(command: funcName)
        }
    }
    
    /// Parse comma-separated arguments, handling quoted strings
    private func parseArguments(_ argsString: String) -> [String] {
        let trimmed = argsString.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return []
        }
        
        var args: [String] = []
        var current = ""
        var inQuotes = false
        var quoteChar: Character = "\""
        
        for char in trimmed {
            if !inQuotes && (char == "\"" || char == "'") {
                inQuotes = true
                quoteChar = char
            } else if inQuotes && char == quoteChar {
                inQuotes = false
            } else if !inQuotes && char == "," {
                args.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        
        if !current.isEmpty {
            args.append(current.trimmingCharacters(in: .whitespaces))
        }
        
        return args
    }

    
    // MARK: - Execution
    
    /// Execute a single command
    private func executeCommand(_ command: Command, context: ScriptContext) async throws {
        switch command {
        case .pressKey(let key):
            context.pressKey(key)
            
        case .releaseKey(let key):
            context.releaseKey(key)
            
        case .tapKey(let key, let duration):
            context.tapKey(key, duration: duration)
            
        case .mouseClick(let button):
            context.mouseClick(button)
            
        case .mouseMove(let dx, let dy):
            context.mouseMove(dx: dx, dy: dy)
            
        case .sleep(let milliseconds):
            await context.sleep(milliseconds)
            
        case .isButtonPressed(let button):
            // This is typically used in conditionals, but for now just query the state
            _ = context.isButtonPressed(button)
        }
    }
    
    // MARK: - AST-Based Execution
    
    /// Execute parsed AST statements
    /// Requirements: 2.6, 2.7 - Execute if statements with then/else blocks
    public func executeStatements(_ statements: [AnyStatement], context: ScriptContext) async throws -> ExecutionControl {
        for statement in statements {
            let control = try await executeStatement(statement, context: context)
            switch control {
            case .normal:
                continue
            case .breakLoop, .continueLoop:
                return control
            }
        }
        return .normal
    }
    
    /// Execute a single AST statement
    /// Requirements: 2.6, 2.7 - Execute if statements
    public func executeStatement(_ statement: AnyStatement, context: ScriptContext) async throws -> ExecutionControl {
        switch statement {
        case .ifStatement(let ifStmt):
            return try await executeIfStatement(ifStmt, context: context)
            
        case .whileStatement(let whileStmt):
            return try await executeWhileStatement(whileStmt, context: context)
            
        case .breakStatement:
            return .breakLoop
            
        case .continueStatement:
            return .continueLoop
            
        case .functionCall(let funcCall):
            try await executeFunctionCall(funcCall, context: context)
            return .normal
        }
    }
    
    /// Execute an if statement
    /// Requirements: 2.6 - Execute then-block when condition is true
    /// Requirements: 2.7 - Execute else-block when condition is false and else exists
    private func executeIfStatement(_ ifStmt: IfStatement, context: ScriptContext) async throws -> ExecutionControl {
        let conditionResult = conditionEvaluator.evaluate(ifStmt.condition, context: context)
        
        if conditionResult {
            // Execute then-block when condition is true
            return try await executeStatements(ifStmt.thenBlock, context: context)
        } else if let elseBlock = ifStmt.elseBlock {
            // Execute else-block when condition is false and else exists
            return try await executeStatements(elseBlock, context: context)
        }
        
        // Skip when condition is false and no else
        return .normal
    }
    
    /// Execute a while statement
    /// Requirements: 3.3 - Continue executing while condition is true
    /// Requirements: 3.4 - Exit when condition becomes false
    /// Requirements: 3.5 - Exit immediately when break is encountered
    /// Requirements: 3.6 - Skip to next iteration when continue is encountered
    private func executeWhileStatement(_ whileStmt: WhileStatement, context: ScriptContext) async throws -> ExecutionControl {
        // Evaluate condition before each iteration (Requirements 3.3, 3.4)
        while conditionEvaluator.evaluate(whileStmt.condition, context: context) {
            // Execute body statements
            for statement in whileStmt.body {
                let control = try await executeStatement(statement, context: context)
                
                switch control {
                case .normal:
                    continue
                case .breakLoop:
                    // Requirements 3.5: Exit loop immediately when break encountered
                    return .normal
                case .continueLoop:
                    // Requirements 3.6: Skip remaining statements, begin next iteration
                    break
                }
            }
        }
        
        // Exit when condition becomes false (Requirements 3.4)
        return .normal
    }
    
    /// Execute a function call statement
    private func executeFunctionCall(_ funcCall: FunctionCallStatement, context: ScriptContext) async throws {
        switch funcCall.name {
        case "pressKey":
            guard funcCall.arguments.count >= 1 else {
                throw ScriptError.syntaxError(line: 0, message: "pressKey requires 1 argument")
            }
            context.pressKey(funcCall.arguments[0])
            
        case "releaseKey":
            guard funcCall.arguments.count >= 1 else {
                throw ScriptError.syntaxError(line: 0, message: "releaseKey requires 1 argument")
            }
            context.releaseKey(funcCall.arguments[0])
            
        case "tapKey":
            guard funcCall.arguments.count >= 2 else {
                throw ScriptError.syntaxError(line: 0, message: "tapKey requires 2 arguments")
            }
            guard let duration = Int(funcCall.arguments[1]) else {
                throw ScriptError.invalidArgument(command: "tapKey", argument: funcCall.arguments[1])
            }
            context.tapKey(funcCall.arguments[0], duration: duration)
            
        case "mouseClick":
            guard funcCall.arguments.count >= 1 else {
                throw ScriptError.syntaxError(line: 0, message: "mouseClick requires 1 argument")
            }
            context.mouseClick(funcCall.arguments[0])
            
        case "mouseMove":
            guard funcCall.arguments.count >= 2 else {
                throw ScriptError.syntaxError(line: 0, message: "mouseMove requires 2 arguments")
            }
            guard let dx = Int(funcCall.arguments[0]), let dy = Int(funcCall.arguments[1]) else {
                throw ScriptError.invalidArgument(command: "mouseMove", argument: "\(funcCall.arguments[0]), \(funcCall.arguments[1])")
            }
            context.mouseMove(dx: dx, dy: dy)
            
        case "sleep":
            guard funcCall.arguments.count >= 1 else {
                throw ScriptError.syntaxError(line: 0, message: "sleep requires 1 argument")
            }
            guard let ms = Int(funcCall.arguments[0]) else {
                throw ScriptError.invalidArgument(command: "sleep", argument: funcCall.arguments[0])
            }
            await context.sleep(ms)
            
        case "isButtonPressed":
            guard funcCall.arguments.count >= 1 else {
                throw ScriptError.syntaxError(line: 0, message: "isButtonPressed requires 1 argument")
            }
            _ = context.isButtonPressed(funcCall.arguments[0])
            
        default:
            throw ScriptError.unknownCommand(command: funcCall.name)
        }
    }
    
    /// Parse and execute a script using AST
    public func executeAST(_ source: String, context: ScriptContext) async throws {
        let statements = try scriptParser.parse(source)
        _ = try await executeStatements(statements, context: context)
    }
}

// MARK: - Default Script Context Implementation

/// Default implementation of ScriptContext that uses EventEmitter
/// Requirements: 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8
public final class DefaultScriptContext: ScriptContext {
    
    private let eventEmitter: EventEmitterProtocol
    private let buttonStateProvider: (String) -> Bool
    
    /// Track emitted events for testing
    public private(set) var emittedKeyPresses: [String] = []
    public private(set) var emittedKeyReleases: [String] = []
    public private(set) var emittedKeyTaps: [(key: String, duration: Int)] = []
    public private(set) var emittedMouseClicks: [String] = []
    public private(set) var emittedMouseMoves: [(dx: Int, dy: Int)] = []
    public private(set) var buttonStateQueries: [String] = []
    
    public init(eventEmitter: EventEmitterProtocol, buttonStateProvider: @escaping (String) -> Bool = { _ in false }) {
        self.eventEmitter = eventEmitter
        self.buttonStateProvider = buttonStateProvider
    }
    
    /// Emit a key press event
    /// Requirements: 12.2 - pressKey(key) SHALL emit a key press event
    public func pressKey(_ key: String) {
        if let keyCode = keyCodeForString(key) {
            eventEmitter.emitKeyDown(keyCode, modifiers: [])
        }
        emittedKeyPresses.append(key)
    }
    
    /// Emit a key release event
    /// Requirements: 12.3 - releaseKey(key) SHALL emit a key release event
    public func releaseKey(_ key: String) {
        if let keyCode = keyCodeForString(key) {
            eventEmitter.emitKeyUp(keyCode, modifiers: [])
        }
        emittedKeyReleases.append(key)
    }
    
    /// Emit a key tap (press + delay + release)
    /// Requirements: 12.4 - tapKey(key, ms) SHALL emit key press, wait, then release
    public func tapKey(_ key: String, duration: Int) {
        if let keyCode = keyCodeForString(key) {
            eventEmitter.emitKeyDown(keyCode, modifiers: [])
            // Note: In real implementation, we'd use async sleep here
            // For synchronous context, we use Thread.sleep
            Thread.sleep(forTimeInterval: Double(duration) / 1000.0)
            eventEmitter.emitKeyUp(keyCode, modifiers: [])
        }
        emittedKeyTaps.append((key: key, duration: duration))
    }
    
    /// Emit a mouse click
    /// Requirements: 12.5 - mouseClick(button) SHALL emit a mouse click event
    public func mouseClick(_ button: String) {
        if let mouseButton = mouseButtonForString(button) {
            eventEmitter.emitMouseDown(mouseButton)
            eventEmitter.emitMouseUp(mouseButton)
        }
        emittedMouseClicks.append(button)
    }
    
    /// Emit a relative mouse movement
    /// Requirements: 12.6 - mouseMove(dx, dy) SHALL emit a relative movement event
    public func mouseMove(dx: Int, dy: Int) {
        eventEmitter.emitMouseMove(dx: CGFloat(dx), dy: CGFloat(dy))
        emittedMouseMoves.append((dx: dx, dy: dy))
    }
    
    /// Pause execution for specified milliseconds
    /// Requirements: 12.7 - sleep(ms) SHALL pause script execution
    public func sleep(_ milliseconds: Int) async {
        try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }
    
    /// Query if a controller button is currently pressed
    /// Requirements: 12.8 - isButtonPressed(btn) SHALL return current pressed state
    public func isButtonPressed(_ button: String) -> Bool {
        buttonStateQueries.append(button)
        return buttonStateProvider(button)
    }
    
    /// Reset all tracked events (for testing)
    public func reset() {
        emittedKeyPresses.removeAll()
        emittedKeyReleases.removeAll()
        emittedKeyTaps.removeAll()
        emittedMouseClicks.removeAll()
        emittedMouseMoves.removeAll()
        buttonStateQueries.removeAll()
    }

    
    // MARK: - Key Code Mapping
    
    /// Convert key string to macOS virtual key code
    private func keyCodeForString(_ key: String) -> UInt16? {
        // Common key mappings using Carbon.HIToolbox constants
        let keyMap: [String: UInt16] = [
            // Letters
            "a": UInt16(kVK_ANSI_A), "b": UInt16(kVK_ANSI_B), "c": UInt16(kVK_ANSI_C),
            "d": UInt16(kVK_ANSI_D), "e": UInt16(kVK_ANSI_E), "f": UInt16(kVK_ANSI_F),
            "g": UInt16(kVK_ANSI_G), "h": UInt16(kVK_ANSI_H), "i": UInt16(kVK_ANSI_I),
            "j": UInt16(kVK_ANSI_J), "k": UInt16(kVK_ANSI_K), "l": UInt16(kVK_ANSI_L),
            "m": UInt16(kVK_ANSI_M), "n": UInt16(kVK_ANSI_N), "o": UInt16(kVK_ANSI_O),
            "p": UInt16(kVK_ANSI_P), "q": UInt16(kVK_ANSI_Q), "r": UInt16(kVK_ANSI_R),
            "s": UInt16(kVK_ANSI_S), "t": UInt16(kVK_ANSI_T), "u": UInt16(kVK_ANSI_U),
            "v": UInt16(kVK_ANSI_V), "w": UInt16(kVK_ANSI_W), "x": UInt16(kVK_ANSI_X),
            "y": UInt16(kVK_ANSI_Y), "z": UInt16(kVK_ANSI_Z),
            // Numbers
            "0": UInt16(kVK_ANSI_0), "1": UInt16(kVK_ANSI_1), "2": UInt16(kVK_ANSI_2),
            "3": UInt16(kVK_ANSI_3), "4": UInt16(kVK_ANSI_4), "5": UInt16(kVK_ANSI_5),
            "6": UInt16(kVK_ANSI_6), "7": UInt16(kVK_ANSI_7), "8": UInt16(kVK_ANSI_8),
            "9": UInt16(kVK_ANSI_9),
            // Special keys
            "space": UInt16(kVK_Space), "return": UInt16(kVK_Return), "enter": UInt16(kVK_Return),
            "tab": UInt16(kVK_Tab), "escape": UInt16(kVK_Escape), "esc": UInt16(kVK_Escape),
            "delete": UInt16(kVK_Delete), "backspace": UInt16(kVK_Delete),
            "forwarddelete": UInt16(kVK_ForwardDelete),
            // Arrow keys
            "up": UInt16(kVK_UpArrow), "down": UInt16(kVK_DownArrow),
            "left": UInt16(kVK_LeftArrow), "right": UInt16(kVK_RightArrow),
            // Function keys
            "f1": UInt16(kVK_F1), "f2": UInt16(kVK_F2), "f3": UInt16(kVK_F3),
            "f4": UInt16(kVK_F4), "f5": UInt16(kVK_F5), "f6": UInt16(kVK_F6),
            "f7": UInt16(kVK_F7), "f8": UInt16(kVK_F8), "f9": UInt16(kVK_F9),
            "f10": UInt16(kVK_F10), "f11": UInt16(kVK_F11), "f12": UInt16(kVK_F12),
            // Modifiers (for direct key events)
            "shift": UInt16(kVK_Shift), "control": UInt16(kVK_Control),
            "ctrl": UInt16(kVK_Control), "option": UInt16(kVK_Option),
            "alt": UInt16(kVK_Option), "command": UInt16(kVK_Command),
            "cmd": UInt16(kVK_Command),
        ]
        
        return keyMap[key.lowercased()]
    }
    
    /// Convert button string to MouseButton
    private func mouseButtonForString(_ button: String) -> MouseButton? {
        switch button.lowercased() {
        case "left": return .left
        case "right": return .right
        case "middle": return .middle
        default: return nil
        }
    }
}

// MARK: - Mock Script Context for Testing

/// Mock implementation of ScriptContext for testing
/// Tracks all API calls without emitting real events
public final class MockScriptContext: ScriptContext {
    
    public private(set) var keyPresses: [String] = []
    public private(set) var keyReleases: [String] = []
    public private(set) var keyTaps: [(key: String, duration: Int)] = []
    public private(set) var mouseClicks: [String] = []
    public private(set) var mouseMoves: [(dx: Int, dy: Int)] = []
    public private(set) var sleepCalls: [Int] = []
    public private(set) var buttonQueries: [String] = []
    
    /// Configurable button states for testing
    public var buttonStates: [String: Bool] = [:]
    
    public init() {}
    
    public func pressKey(_ key: String) {
        keyPresses.append(key)
    }
    
    public func releaseKey(_ key: String) {
        keyReleases.append(key)
    }
    
    public func tapKey(_ key: String, duration: Int) {
        keyTaps.append((key: key, duration: duration))
    }
    
    public func mouseClick(_ button: String) {
        mouseClicks.append(button)
    }
    
    public func mouseMove(dx: Int, dy: Int) {
        mouseMoves.append((dx: dx, dy: dy))
    }
    
    public func sleep(_ milliseconds: Int) async {
        sleepCalls.append(milliseconds)
        // Don't actually sleep in tests
    }
    
    public func isButtonPressed(_ button: String) -> Bool {
        buttonQueries.append(button)
        return buttonStates[button] ?? false
    }
    
    public func reset() {
        keyPresses.removeAll()
        keyReleases.removeAll()
        keyTaps.removeAll()
        mouseClicks.removeAll()
        mouseMoves.removeAll()
        sleepCalls.removeAll()
        buttonQueries.removeAll()
        buttonStates.removeAll()
    }
}
