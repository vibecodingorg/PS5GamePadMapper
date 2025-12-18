import Foundation

/// Parser for script control flow statements
/// Requirements: 2.1, 2.2, 3.1 - Parse if/else and while statements
public final class ScriptParser {
    
    private var source: String = ""
    private var currentIndex: String.Index!
    private var currentLine: Int = 1
    private var currentColumn: Int = 1
    
    public init() {}
    
    // MARK: - Public API
    
    /// Parse script source into statements
    public func parse(_ source: String) throws -> [AnyStatement] {
        self.source = source
        self.currentIndex = source.startIndex
        self.currentLine = 1
        self.currentColumn = 1
        
        var statements: [AnyStatement] = []
        
        while !isAtEnd {
            skipWhitespaceAndComments()
            if isAtEnd { break }
            
            let statement = try parseStatement()
            statements.append(statement)
        }
        
        return statements
    }
    
    /// Parse a condition expression from string
    public func parseCondition(_ source: String) throws -> ConditionExpression {
        self.source = source
        self.currentIndex = source.startIndex
        self.currentLine = 1
        self.currentColumn = 1
        
        return try parseConditionExpression()
    }
    
    // MARK: - Statement Parsing
    
    private func parseStatement() throws -> AnyStatement {
        skipWhitespaceAndComments()
        
        if match("if") {
            return try parseIfStatement()
        } else if match("while") {
            return try parseWhileStatement()
        } else if match("break") {
            skipWhitespaceAndComments()
            return .breakStatement(BreakStatement())
        } else if match("continue") {
            skipWhitespaceAndComments()
            return .continueStatement(ContinueStatement())
        } else {
            return try parseFunctionCall()
        }
    }
    
    private func parseIfStatement() throws -> AnyStatement {
        skipWhitespaceAndComments()
        
        // Parse condition
        try expect("(")
        let condition = try parseConditionExpression()
        try expect(")")
        
        skipWhitespaceAndComments()
        
        // Parse then block
        let thenBlock = try parseBlock()
        
        skipWhitespaceAndComments()
        
        // Check for else
        var elseBlock: [AnyStatement]? = nil
        if match("else") {
            skipWhitespaceAndComments()
            elseBlock = try parseBlock()
        }
        
        return .ifStatement(IfStatement(condition: condition, thenBlock: thenBlock, elseBlock: elseBlock))
    }
    
    private func parseWhileStatement() throws -> AnyStatement {
        skipWhitespaceAndComments()
        
        // Parse condition
        try expect("(")
        let condition = try parseConditionExpression()
        try expect(")")
        
        skipWhitespaceAndComments()
        
        // Parse body
        let body = try parseBlock()
        
        return .whileStatement(WhileStatement(condition: condition, body: body))
    }
    
    private func parseBlock() throws -> [AnyStatement] {
        try expect("{")
        
        var statements: [AnyStatement] = []
        
        while !isAtEnd {
            skipWhitespaceAndComments()
            
            if check("}") {
                break
            }
            
            let statement = try parseStatement()
            statements.append(statement)
        }
        
        try expect("}")
        
        return statements
    }
    
    private func parseFunctionCall() throws -> AnyStatement {
        let name = try parseIdentifier()
        skipWhitespaceAndComments()
        
        try expect("(")
        let arguments = try parseArguments()
        try expect(")")
        
        return .functionCall(FunctionCallStatement(name: name, arguments: arguments))
    }
    
    private func parseArguments() -> [String] {
        var args: [String] = []
        
        skipWhitespaceAndComments()
        
        if check(")") {
            return args
        }
        
        while !isAtEnd && !check(")") {
            skipWhitespaceAndComments()
            
            var arg = ""
            var inQuotes = false
            var quoteChar: Character = "\""
            
            while !isAtEnd {
                let char = peek()
                
                if !inQuotes && (char == "\"" || char == "'") {
                    inQuotes = true
                    quoteChar = char
                    advance()
                } else if inQuotes && char == quoteChar {
                    inQuotes = false
                    advance()
                } else if !inQuotes && (char == "," || char == ")") {
                    break
                } else {
                    arg.append(char)
                    advance()
                }
            }
            
            args.append(arg.trimmingCharacters(in: .whitespaces))
            
            skipWhitespaceAndComments()
            if check(",") {
                advance()
            }
        }
        
        return args
    }
    
    // MARK: - Condition Expression Parsing
    
    private func parseConditionExpression() throws -> ConditionExpression {
        return try parseOrExpression()
    }
    
    private func parseOrExpression() throws -> ConditionExpression {
        var left = try parseAndExpression()
        
        skipWhitespaceAndComments()
        while check("|") && peekNext() == "|" {
            advance() // consume first |
            advance() // consume second |
            skipWhitespaceAndComments()
            let right = try parseAndExpression()
            left = .or(left, right)
            skipWhitespaceAndComments()
        }
        
        return left
    }
    
    private func parseAndExpression() throws -> ConditionExpression {
        var left = try parseNotExpression()
        
        skipWhitespaceAndComments()
        while check("&") && peekNext() == "&" {
            advance() // consume first &
            advance() // consume second &
            skipWhitespaceAndComments()
            let right = try parseNotExpression()
            left = .and(left, right)
            skipWhitespaceAndComments()
        }
        
        return left
    }
    
    private func parseNotExpression() throws -> ConditionExpression {
        skipWhitespaceAndComments()
        
        if check("!") && !check("!=") {
            advance() // consume '!'
            skipWhitespaceAndComments()
            let expr = try parsePrimaryCondition()
            return .not(expr)
        }
        
        return try parsePrimaryCondition()
    }
    
    private func parsePrimaryCondition() throws -> ConditionExpression {
        skipWhitespaceAndComments()
        
        // Parenthesized expression
        if match("(") {
            let expr = try parseConditionExpression()
            try expect(")")
            return expr
        }
        
        // Boolean literals
        if match("true") {
            return .boolLiteral(true)
        }
        if match("false") {
            return .boolLiteral(false)
        }
        
        // Function call (isButtonPressed)
        if matchWord("isButtonPressed") {
            try expect("(")
            skipWhitespaceAndComments()
            let button = try parseStringOrIdentifier()
            skipWhitespaceAndComments()
            try expect(")")
            return .buttonPressed(button: button)
        }
        
        // Integer comparison
        let left = try parseIntExpression()
        skipWhitespaceAndComments()
        
        let op = try parseComparisonOperator()
        skipWhitespaceAndComments()
        
        let right = try parseIntExpression()
        
        return .intComparison(left: left, op: op, right: right)
    }
    
    private func parseIntExpression() throws -> IntExpression {
        skipWhitespaceAndComments()
        
        // Check for negative number
        let isNegative = match("-")
        
        if let number = parseNumber() {
            return .literal(isNegative ? -number : number)
        }
        
        let identifier = try parseIdentifier()
        return .variable(identifier)
    }
    
    private func parseComparisonOperator() throws -> ComparisonOperator {
        for op in ComparisonOperator.allCases.sorted(by: { $0.rawValue.count > $1.rawValue.count }) {
            if match(op.rawValue) {
                return op
            }
        }
        
        throw ParseError(line: currentLine, column: currentColumn, message: "Expected comparison operator")
    }
    
    private func parseStringOrIdentifier() throws -> String {
        skipWhitespaceAndComments()
        
        // Quoted string
        if check("\"") || check("'") {
            let quote = peek()
            advance()
            
            var result = ""
            while !isAtEnd && peek() != quote {
                result.append(peek())
                advance()
            }
            
            if !isAtEnd {
                advance() // consume closing quote
            }
            
            return result
        }
        
        // Identifier
        return try parseIdentifier()
    }
    
    // MARK: - Helper Methods
    
    private var isAtEnd: Bool {
        currentIndex >= source.endIndex
    }
    
    private func peek() -> Character {
        guard !isAtEnd else { return "\0" }
        return source[currentIndex]
    }
    
    private func peekNext() -> Character {
        let nextIndex = source.index(after: currentIndex)
        guard nextIndex < source.endIndex else { return "\0" }
        return source[nextIndex]
    }
    
    @discardableResult
    private func advance() -> Character {
        guard !isAtEnd else { return "\0" }
        let char = source[currentIndex]
        currentIndex = source.index(after: currentIndex)
        
        if char == "\n" {
            currentLine += 1
            currentColumn = 1
        } else {
            currentColumn += 1
        }
        
        return char
    }
    
    private func check(_ expected: String) -> Bool {
        guard !isAtEnd else { return false }
        
        var tempIndex: String.Index = currentIndex
        for char in expected {
            guard tempIndex < source.endIndex, source[tempIndex] == char else {
                return false
            }
            tempIndex = source.index(after: tempIndex)
        }
        return true
    }
    
    private func match(_ expected: String) -> Bool {
        if check(expected) {
            for _ in expected {
                advance()
            }
            return true
        }
        return false
    }
    
    private func matchWord(_ word: String) -> Bool {
        guard check(word) else { return false }
        
        // Check that the next character is not alphanumeric
        var tempIndex: String.Index = currentIndex
        for _ in word {
            guard tempIndex < source.endIndex else { break }
            tempIndex = source.index(after: tempIndex)
        }
        
        if tempIndex < source.endIndex {
            let nextChar = source[tempIndex]
            if nextChar.isLetter || nextChar.isNumber || nextChar == "_" {
                return false
            }
        }
        
        for _ in word {
            advance()
        }
        return true
    }
    
    private func expect(_ expected: String) throws {
        skipWhitespaceAndComments()
        if !match(expected) {
            throw ParseError(line: currentLine, column: currentColumn, message: "Expected '\(expected)'")
        }
    }
    
    private func skipWhitespaceAndComments() {
        while !isAtEnd {
            let char = peek()
            
            if char.isWhitespace {
                advance()
            } else if char == "/" && peekNext() == "/" {
                // Line comment
                while !isAtEnd && peek() != "\n" {
                    advance()
                }
            } else if char == "#" {
                // Hash comment
                while !isAtEnd && peek() != "\n" {
                    advance()
                }
            } else {
                break
            }
        }
    }
    
    private func parseIdentifier() throws -> String {
        skipWhitespaceAndComments()
        
        var result = ""
        
        guard !isAtEnd else {
            throw ParseError(line: currentLine, column: currentColumn, message: "Expected identifier")
        }
        
        let firstChar = peek()
        guard firstChar.isLetter || firstChar == "_" else {
            throw ParseError(line: currentLine, column: currentColumn, message: "Expected identifier, got '\(firstChar)'")
        }
        
        while !isAtEnd {
            let char = peek()
            if char.isLetter || char.isNumber || char == "_" {
                result.append(char)
                advance()
            } else {
                break
            }
        }
        
        return result
    }
    
    private func parseNumber() -> Int? {
        skipWhitespaceAndComments()
        
        var result = ""
        
        while !isAtEnd && peek().isNumber {
            result.append(peek())
            advance()
        }
        
        return Int(result)
    }
}

// MARK: - Pretty Printer

/// Pretty printer for AST nodes (for round-trip testing)
public final class ScriptPrettyPrinter {
    
    private var indentLevel: Int = 0
    private let indentString = "    "
    
    public init() {}
    
    public func print(_ statements: [AnyStatement]) -> String {
        return statements.map { printStatement($0) }.joined(separator: "\n")
    }
    
    public func printCondition(_ condition: ConditionExpression) -> String {
        switch condition {
        case .buttonPressed(let button):
            return "isButtonPressed(\"\(button)\")"
        case .boolLiteral(let value):
            return value ? "true" : "false"
        case .intComparison(let left, let op, let right):
            return "\(printIntExpr(left)) \(op.rawValue) \(printIntExpr(right))"
        case .not(let expr):
            return "!\(printCondition(expr))"
        case .and(let left, let right):
            return "(\(printCondition(left)) && \(printCondition(right)))"
        case .or(let left, let right):
            return "(\(printCondition(left)) || \(printCondition(right)))"
        }
    }
    
    private func printStatement(_ statement: AnyStatement) -> String {
        switch statement {
        case .ifStatement(let s):
            return printIfStatement(s)
        case .whileStatement(let s):
            return printWhileStatement(s)
        case .breakStatement:
            return indent() + "break"
        case .continueStatement:
            return indent() + "continue"
        case .functionCall(let s):
            return printFunctionCall(s)
        }
    }
    
    private func printIfStatement(_ s: IfStatement) -> String {
        var result = indent() + "if (\(printCondition(s.condition))) {\n"
        indentLevel += 1
        result += s.thenBlock.map { printStatement($0) }.joined(separator: "\n")
        indentLevel -= 1
        result += "\n" + indent() + "}"
        
        if let elseBlock = s.elseBlock {
            result += " else {\n"
            indentLevel += 1
            result += elseBlock.map { printStatement($0) }.joined(separator: "\n")
            indentLevel -= 1
            result += "\n" + indent() + "}"
        }
        
        return result
    }
    
    private func printWhileStatement(_ s: WhileStatement) -> String {
        var result = indent() + "while (\(printCondition(s.condition))) {\n"
        indentLevel += 1
        result += s.body.map { printStatement($0) }.joined(separator: "\n")
        indentLevel -= 1
        result += "\n" + indent() + "}"
        return result
    }
    
    private func printFunctionCall(_ s: FunctionCallStatement) -> String {
        let args = s.arguments.map { "\"\($0)\"" }.joined(separator: ", ")
        return indent() + "\(s.name)(\(args))"
    }
    
    private func printIntExpr(_ expr: IntExpression) -> String {
        switch expr {
        case .literal(let value):
            return String(value)
        case .variable(let name):
            return name
        }
    }
    
    private func indent() -> String {
        return String(repeating: indentString, count: indentLevel)
    }
}
