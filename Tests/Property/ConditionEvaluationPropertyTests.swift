import XCTest
import SwiftCheck
@testable import PS5GamePadMapperCore

/// Property tests for condition expression evaluation
/// **Feature: macro-script-enhancements, Property 6: Condition Expression Evaluation**
final class ConditionEvaluationPropertyTests: XCTestCase {
    
    var evaluator: ConditionEvaluator!
    var mockContext: MockScriptContext!
    
    override func setUp() {
        super.setUp()
        evaluator = ConditionEvaluator()
        mockContext = MockScriptContext()
    }
    
    // MARK: - Property 6: Condition Expression Evaluation
    
    /// **Feature: macro-script-enhancements, Property 6: Condition Expression Evaluation**
    /// **Validates: Requirements 2.3, 2.4, 2.5, 3.2**
    /// For any condition expression with button states, comparison operators, and logical
    /// operators, the evaluation result SHALL match the expected boolean logic.
    func testConditionExpressionEvaluation() {
        property("Boolean literals evaluate correctly") <- forAll { (value: Bool) in
            let condition = ConditionExpression.boolLiteral(value)
            return self.evaluator.evaluate(condition, context: self.mockContext) == value
        }
    }
    
    /// Test button pressed condition evaluation
    func testButtonPressedEvaluation() {
        property("Button pressed evaluates based on context") <- forAll { (button: String, isPressed: Bool) in
            self.mockContext.buttonStates[button] = isPressed
            let condition = ConditionExpression.buttonPressed(button: button)
            return self.evaluator.evaluate(condition, context: self.mockContext) == isPressed
        }
    }
    
    /// Test NOT operator
    func testNotOperator() {
        property("NOT inverts the result") <- forAll { (value: Bool) in
            let inner = ConditionExpression.boolLiteral(value)
            let condition = ConditionExpression.not(inner)
            return self.evaluator.evaluate(condition, context: self.mockContext) == !value
        }
    }
    
    /// Test AND operator
    func testAndOperator() {
        property("AND follows boolean logic") <- forAll { (left: Bool, right: Bool) in
            let leftExpr = ConditionExpression.boolLiteral(left)
            let rightExpr = ConditionExpression.boolLiteral(right)
            let condition = ConditionExpression.and(leftExpr, rightExpr)
            return self.evaluator.evaluate(condition, context: self.mockContext) == (left && right)
        }
    }
    
    /// Test OR operator
    func testOrOperator() {
        property("OR follows boolean logic") <- forAll { (left: Bool, right: Bool) in
            let leftExpr = ConditionExpression.boolLiteral(left)
            let rightExpr = ConditionExpression.boolLiteral(right)
            let condition = ConditionExpression.or(leftExpr, rightExpr)
            return self.evaluator.evaluate(condition, context: self.mockContext) == (left || right)
        }
    }
    
    /// Test comparison operators
    func testComparisonOperators() {
        property("Comparison operators evaluate correctly") <- forAll(
            Gen<Int>.fromElements(in: -100...100),
            Gen<Int>.fromElements(in: -100...100)
        ) { (left, right) in
            // Test all comparison operators
            let tests: [(ComparisonOperator, Bool)] = [
                (.equal, left == right),
                (.notEqual, left != right),
                (.lessThan, left < right),
                (.greaterThan, left > right),
                (.lessOrEqual, left <= right),
                (.greaterOrEqual, left >= right)
            ]
            
            for (op, expected) in tests {
                let condition = ConditionExpression.intComparison(
                    left: .literal(left),
                    op: op,
                    right: .literal(right)
                )
                if self.evaluator.evaluate(condition, context: self.mockContext) != expected {
                    return false
                }
            }
            
            return true
        }
    }
    
    /// Test variable comparison
    func testVariableComparison() {
        evaluator.variables["x"] = 10
        evaluator.variables["y"] = 20
        
        let condition = ConditionExpression.intComparison(
            left: .variable("x"),
            op: .lessThan,
            right: .variable("y")
        )
        
        XCTAssertTrue(evaluator.evaluate(condition, context: mockContext))
    }
    
    /// Test complex nested conditions
    func testComplexNestedConditions() {
        // (true && false) || true = true
        let condition = ConditionExpression.or(
            .and(.boolLiteral(true), .boolLiteral(false)),
            .boolLiteral(true)
        )
        
        XCTAssertTrue(evaluator.evaluate(condition, context: mockContext))
        
        // !(true && false) = true
        let condition2 = ConditionExpression.not(
            .and(.boolLiteral(true), .boolLiteral(false))
        )
        
        XCTAssertTrue(evaluator.evaluate(condition2, context: mockContext))
    }
}
