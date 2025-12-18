import Foundation

/// Protocol for condition evaluation
public protocol ConditionEvaluatorProtocol {
    func evaluate(_ condition: ConditionExpression, context: ScriptContext) -> Bool
}

/// Evaluates condition expressions
/// Requirements: 2.3, 2.4, 2.5 - Support button state, comparison, and logical operators
public final class ConditionEvaluator: ConditionEvaluatorProtocol {
    
    /// Variable values for comparison expressions
    public var variables: [String: Int] = [:]
    
    public init() {}
    
    /// Evaluate a condition expression
    public func evaluate(_ condition: ConditionExpression, context: ScriptContext) -> Bool {
        switch condition {
        case .buttonPressed(let button):
            return context.isButtonPressed(button)
            
        case .boolLiteral(let value):
            return value
            
        case .intComparison(let left, let op, let right):
            let leftValue = evaluateIntExpression(left)
            let rightValue = evaluateIntExpression(right)
            return evaluateComparison(leftValue, op, rightValue)
            
        case .not(let expr):
            return !evaluate(expr, context: context)
            
        case .and(let left, let right):
            return evaluate(left, context: context) && evaluate(right, context: context)
            
        case .or(let left, let right):
            return evaluate(left, context: context) || evaluate(right, context: context)
        }
    }
    
    /// Evaluate an integer expression
    private func evaluateIntExpression(_ expr: IntExpression) -> Int {
        switch expr {
        case .literal(let value):
            return value
        case .variable(let name):
            return variables[name] ?? 0
        }
    }
    
    /// Evaluate a comparison operation
    private func evaluateComparison(_ left: Int, _ op: ComparisonOperator, _ right: Int) -> Bool {
        switch op {
        case .equal:
            return left == right
        case .notEqual:
            return left != right
        case .lessThan:
            return left < right
        case .greaterThan:
            return left > right
        case .lessOrEqual:
            return left <= right
        case .greaterOrEqual:
            return left >= right
        }
    }
}
