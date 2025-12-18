import Foundation
import SwiftCheck
@testable import PS5GamePadMapperCore

// MARK: - Condition Expression Generator

extension ConditionExpression: Arbitrary {
    public static var arbitrary: Gen<ConditionExpression> {
        return Gen.sized { size in
            if size <= 1 {
                return simpleConditionGen
            } else {
                return Gen.frequency([
                    (3, simpleConditionGen),
                    (1, compoundConditionGen(size: size))
                ])
            }
        }
    }
    
    private static var simpleConditionGen: Gen<ConditionExpression> {
        return Gen.one(of: [
            buttonPressedGen,
            boolLiteralGen,
            intComparisonGen
        ])
    }
    
    private static var buttonPressedGen: Gen<ConditionExpression> {
        let buttons = ["X", "O", "Square", "Triangle", "L1", "R1", "L2", "R2"]
        return Gen<String>.fromElements(of: buttons).map { .buttonPressed(button: $0) }
    }
    
    private static var boolLiteralGen: Gen<ConditionExpression> {
        return Bool.arbitrary.map { .boolLiteral($0) }
    }
    
    private static var intComparisonGen: Gen<ConditionExpression> {
        return Gen<ConditionExpression>.compose { c in
            let left = c.generate(using: IntExpression.arbitrary)
            let op = c.generate(using: ComparisonOperator.arbitrary)
            let right = c.generate(using: IntExpression.arbitrary)
            return .intComparison(left: left, op: op, right: right)
        }
    }
    
    private static func compoundConditionGen(size: Int) -> Gen<ConditionExpression> {
        return Gen.one(of: [
            simpleConditionGen.map { .not($0) },
            Gen<ConditionExpression>.compose { c in
                let left = c.generate(using: simpleConditionGen)
                let right = c.generate(using: simpleConditionGen)
                return .and(left, right)
            },
            Gen<ConditionExpression>.compose { c in
                let left = c.generate(using: simpleConditionGen)
                let right = c.generate(using: simpleConditionGen)
                return .or(left, right)
            }
        ])
    }
}

extension IntExpression: Arbitrary {
    public static var arbitrary: Gen<IntExpression> {
        return Gen.one(of: [
            Gen<Int>.fromElements(in: -100...100).map { .literal($0) },
            Gen<String>.fromElements(of: ["x", "y", "count", "value"]).map { .variable($0) }
        ])
    }
}

extension ComparisonOperator: Arbitrary {
    public static var arbitrary: Gen<ComparisonOperator> {
        return Gen.fromElements(of: ComparisonOperator.allCases)
    }
}

// MARK: - Statement Generator

extension FunctionCallStatement: Arbitrary {
    public static var arbitrary: Gen<FunctionCallStatement> {
        let functions: [(String, Int)] = [
            ("pressKey", 1),
            ("releaseKey", 1),
            ("tapKey", 2),
            ("mouseClick", 1),
            ("mouseMove", 2),
            ("sleep", 1)
        ]
        
        return Gen.fromElements(of: functions).flatMap { (name, argCount) in
            let args: [String]
            switch name {
            case "pressKey", "releaseKey":
                args = ["a"]
            case "tapKey":
                args = ["a", "100"]
            case "mouseClick":
                args = ["left"]
            case "mouseMove":
                args = ["10", "20"]
            case "sleep":
                args = ["100"]
            default:
                args = []
            }
            return Gen.pure(FunctionCallStatement(name: name, arguments: args))
        }
    }
}

extension AnyStatement: Arbitrary {
    public static var arbitrary: Gen<AnyStatement> {
        return Gen.sized { size in
            if size <= 1 {
                return simpleFunctionCallGen
            } else {
                return Gen.frequency([
                    (5, simpleFunctionCallGen),
                    (2, ifStatementGen(size: size)),
                    (2, whileStatementGen(size: size)),
                    (1, Gen.pure(.breakStatement(BreakStatement()))),
                    (1, Gen.pure(.continueStatement(ContinueStatement())))
                ])
            }
        }
    }
    
    private static var simpleFunctionCallGen: Gen<AnyStatement> {
        return FunctionCallStatement.arbitrary.map { .functionCall($0) }
    }
    
    private static func ifStatementGen(size: Int) -> Gen<AnyStatement> {
        return Gen<AnyStatement>.compose { c in
            let condition = c.generate(using: simpleConditionGen)
            let thenCount = c.generate(using: Gen<Int>.fromElements(in: 1...2))
            var thenBlock: [AnyStatement] = []
            for _ in 0..<thenCount {
                thenBlock.append(c.generate(using: simpleFunctionCallGen))
            }
            
            let hasElse = c.generate(using: Bool.arbitrary)
            var elseBlock: [AnyStatement]? = nil
            if hasElse {
                let elseCount = c.generate(using: Gen<Int>.fromElements(in: 1...2))
                elseBlock = []
                for _ in 0..<elseCount {
                    elseBlock?.append(c.generate(using: simpleFunctionCallGen))
                }
            }
            
            return .ifStatement(IfStatement(condition: condition, thenBlock: thenBlock, elseBlock: elseBlock))
        }
    }
    
    private static func whileStatementGen(size: Int) -> Gen<AnyStatement> {
        return Gen<AnyStatement>.compose { c in
            let condition = c.generate(using: simpleConditionGen)
            let bodyCount = c.generate(using: Gen<Int>.fromElements(in: 1...2))
            var body: [AnyStatement] = []
            for _ in 0..<bodyCount {
                body.append(c.generate(using: simpleFunctionCallGen))
            }
            
            return .whileStatement(WhileStatement(condition: condition, body: body))
        }
    }
    
    private static var simpleConditionGen: Gen<ConditionExpression> {
        let buttons = ["X", "O", "Square", "Triangle", "L1", "R1"]
        return Gen<String>.fromElements(of: buttons).map { .buttonPressed(button: $0) }
    }
}

// MARK: - Simple Statement List Generator

/// Generator for a list of simple statements (no nested control flow)
public struct SimpleStatementList {
    public let statements: [AnyStatement]
}

extension SimpleStatementList: Arbitrary {
    public static var arbitrary: Gen<SimpleStatementList> {
        return Gen<Int>.fromElements(in: 1...5).flatMap { count in
            Gen<SimpleStatementList>.compose { c in
                var statements: [AnyStatement] = []
                for _ in 0..<count {
                    statements.append(c.generate(using: FunctionCallStatement.arbitrary.map { .functionCall($0) }))
                }
                return SimpleStatementList(statements: statements)
            }
        }
    }
}
