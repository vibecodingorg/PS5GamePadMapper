import Foundation

// MARK: - Statement Protocol

/// Base protocol for all executable statements
public protocol Statement: Equatable {}

// MARK: - Condition Expression

/// A condition expression that evaluates to boolean
/// Requirements: 2.3, 2.4, 2.5 - Support button state, comparison, and logical operators
public indirect enum ConditionExpression: Equatable, Codable {
    case buttonPressed(button: String)
    case boolLiteral(Bool)
    case intComparison(left: IntExpression, op: ComparisonOperator, right: IntExpression)
    case not(ConditionExpression)
    case and(ConditionExpression, ConditionExpression)
    case or(ConditionExpression, ConditionExpression)
}

/// Comparison operators for condition expressions
/// Requirements: 2.4 - Support ==, !=, <, >, <=, >=
public enum ComparisonOperator: String, Codable, Equatable, CaseIterable {
    case equal = "=="
    case notEqual = "!="
    case lessThan = "<"
    case greaterThan = ">"
    case lessOrEqual = "<="
    case greaterOrEqual = ">="
}

/// Integer expression for comparisons
public enum IntExpression: Equatable, Codable {
    case literal(Int)
    case variable(String)
}

// MARK: - Statements

/// If statement with optional else block
/// Requirements: 2.1, 2.2 - Support if and if-else syntax
public struct IfStatement: Statement {
    public let condition: ConditionExpression
    public let thenBlock: [AnyStatement]
    public let elseBlock: [AnyStatement]?
    
    public init(condition: ConditionExpression, thenBlock: [AnyStatement], elseBlock: [AnyStatement]? = nil) {
        self.condition = condition
        self.thenBlock = thenBlock
        self.elseBlock = elseBlock
    }
    
    public static func == (lhs: IfStatement, rhs: IfStatement) -> Bool {
        lhs.condition == rhs.condition &&
        lhs.thenBlock == rhs.thenBlock &&
        lhs.elseBlock == rhs.elseBlock
    }
}

/// While loop statement
/// Requirements: 3.1 - Support while syntax
public struct WhileStatement: Statement {
    public let condition: ConditionExpression
    public let body: [AnyStatement]
    
    public init(condition: ConditionExpression, body: [AnyStatement]) {
        self.condition = condition
        self.body = body
    }
    
    public static func == (lhs: WhileStatement, rhs: WhileStatement) -> Bool {
        lhs.condition == rhs.condition && lhs.body == rhs.body
    }
}

/// Break statement for exiting loops
/// Requirements: 3.5 - Support break statement
public struct BreakStatement: Statement {
    public init() {}
}

/// Continue statement for skipping to next iteration
/// Requirements: 3.6 - Support continue statement
public struct ContinueStatement: Statement {
    public init() {}
}

/// Function call statement (existing commands)
public struct FunctionCallStatement: Statement {
    public let name: String
    public let arguments: [String]
    
    public init(name: String, arguments: [String]) {
        self.name = name
        self.arguments = arguments
    }
}

// MARK: - Type-Erased Statement Wrapper

/// Type-erased wrapper for statements to allow heterogeneous collections
public enum AnyStatement: Equatable {
    case ifStatement(IfStatement)
    case whileStatement(WhileStatement)
    case breakStatement(BreakStatement)
    case continueStatement(ContinueStatement)
    case functionCall(FunctionCallStatement)
    
    public var statement: any Statement {
        switch self {
        case .ifStatement(let s): return s
        case .whileStatement(let s): return s
        case .breakStatement(let s): return s
        case .continueStatement(let s): return s
        case .functionCall(let s): return s
        }
    }
}

// MARK: - Execution Control

/// Execution result for control flow
public enum ExecutionControl: Equatable {
    case normal
    case breakLoop
    case continueLoop
}

// MARK: - Parse Error

/// Error during script parsing
public struct ParseError: Error, Equatable {
    public let line: Int
    public let column: Int
    public let message: String
    
    public init(line: Int, column: Int, message: String) {
        self.line = line
        self.column = column
        self.message = message
    }
}

// MARK: - Parse Result

/// Result of parsing a script
public struct ParseResult {
    public let statements: [AnyStatement]
    public let errors: [ParseError]
    
    public var isSuccess: Bool { errors.isEmpty }
    
    public init(statements: [AnyStatement], errors: [ParseError] = []) {
        self.statements = statements
        self.errors = errors
    }
}
