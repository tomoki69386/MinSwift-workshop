import Foundation
import SwiftSyntax

class Parser: SyntaxVisitor {
    private(set) var tokens: [TokenSyntax] = []
    private var index = 0
    private(set) var currentToken: TokenSyntax!

    // MARK: Practice 1

    override func visit(_ token: TokenSyntax) {
        print(token.tokenKind)
        tokens.append(token)
    }

    @discardableResult
    func read() -> TokenSyntax {
        currentToken = tokens[index]
        index += 1
        return currentToken
    }

    func peek(_ n: Int = 0) -> TokenSyntax {
        return tokens[n + 1]
    }

    // MARK: Practice 2

    private func extractNumberLiteral(from token: TokenSyntax) -> Double? {
        switch token.tokenKind {
        case .integerLiteral(let string):
            return Double(string)
        case .floatingLiteral(let string):
            return Double(string)
        default:
            return nil
        }
    }

    func parseNumber() -> Node {
        guard let value = extractNumberLiteral(from: currentToken) else {
            fatalError("any number is expected")
        }
        read() // eat literal
        return NumberNode(value: value)
    }

    func parseIdentifierExpression() -> Node {
        switch currentToken.tokenKind {
        case .identifier(let string):
            read()
            if case .leftParen = currentToken.tokenKind {
                read()
                if case .colon = currentToken.tokenKind {
                    
                }
                read()
                return CallExpressionNode(callee: string, arguments: [])
            } else {
                return VariableNode(identifier: string)
            }
        default:
            fatalError("")
        }
    }

    // MARK: Practice 3

    func extractBinaryOperator(from token: TokenSyntax) -> BinaryExpressionNode.Operator? {
        switch token.tokenKind {
        case .spacedBinaryOperator(let string):
            return BinaryExpressionNode.Operator(rawValue: string)
        default:
            return nil
        }
    }

    private func parseBinaryOperatorRHS(expressionPrecedence: Int, lhs: Node?) -> Node? {
        var currentLHS: Node? = lhs
        while true {
            let binaryOperator = extractBinaryOperator(from: currentToken!)
            let operatorPrecedence = binaryOperator?.precedence ?? -1
            
            // Compare between nextOperator's precedences and current one
            if operatorPrecedence < expressionPrecedence {
                return currentLHS
            }
            
            read() // eat binary operator
            var rhs = parsePrimary()
            if rhs == nil {
                return nil
            }
            
            // If binOperator binds less tightly with RHS than the operator after RHS, let
            // the pending operator take RHS as its LHS.
            let nextPrecedence = extractBinaryOperator(from: currentToken)?.precedence ?? -1
            if (operatorPrecedence < nextPrecedence) {
                // Search next RHS from currentRHS
                // next precedence will be `operatorPrecedence + 1`
                rhs = parseBinaryOperatorRHS(expressionPrecedence: operatorPrecedence + 1, lhs: rhs)
                if rhs == nil {
                    return nil
                }
            }
            
            guard let nonOptionalRHS = rhs else {
                fatalError("rhs must be nonnull")
            }
            
            currentLHS = BinaryExpressionNode(binaryOperator!,
                                              lhs: currentLHS!,
                                              rhs: nonOptionalRHS)
        }
    }

    // MARK: Practice 4

    func parseFunctionDefinitionArgument() -> FunctionNode.Argument {
        switch currentToken.tokenKind {
        case .identifier(let string1):
            read()
            read()
            read()
            return FunctionNode.Argument(label: string1, variableName: string1)
        default:
            fatalError("")
        }
    }

    func parseFunctionDefinition() -> Node {
        guard case .funcKeyword = currentToken.tokenKind else {
            fatalError("error")
        }
        read()
        
        guard case .identifier(let funcName) = currentToken.tokenKind else {
            fatalError("error")
        }
        read()
        
        guard case .leftParen = currentToken.tokenKind else {
            fatalError("error")
        }
        read()
        
        var arguments = [FunctionNode.Argument]()
        while true {
            if case .rightParen = currentToken.tokenKind {
                break
            }
            
            guard case .identifier(let labelName) = currentToken.tokenKind else {
                fatalError("\(currentToken.tokenKind)")
            }
            
            arguments.append(FunctionNode.Argument(label: labelName, variableName: labelName))
            read()
            read()
            read()
        }
        read()
        
        guard case .arrow = currentToken.tokenKind else {
            fatalError("error")
        }
        read()
        
        guard case .identifier(let returnTypeName) = currentToken.tokenKind else {
            fatalError("error")
        }
        read()
        
        let type = Type(rawValue: returnTypeName)!
        
        guard case .leftBrace = currentToken.tokenKind else {
            fatalError("error")
        }
        read()
        
        let body = parseExpression()!
        
        guard case .rightBrace = currentToken.tokenKind else {
            fatalError("error")
        }
        read()
        
//        return VariableNode(identifier: string)
        return FunctionNode(name: funcName, arguments: arguments, returnType: type, body: body)
    }

    // MARK: Practice 7

    func parseIfElse() -> Node {
        fatalError("Not Implemented")
    }

    // PROBABLY WORKS WELL, TRUST ME

    func parse() -> [Node] {
        var nodes: [Node] = []
        read()
        while true {
            switch currentToken.tokenKind {
            case .eof:
                return nodes
            case .funcKeyword:
                let node = parseFunctionDefinition()
                nodes.append(node)
            default:
                if let node = parseTopLevelExpression() {
                    nodes.append(node)
                    break
                } else {
                    read()
                }
            }
        }
        return nodes
    }

    private func parsePrimary() -> Node? {
        switch currentToken.tokenKind {
        case .identifier:
            return parseIdentifierExpression()
        case .integerLiteral, .floatingLiteral:
            return parseNumber()
        case .leftParen:
            return parseParen()
        case .funcKeyword:
            return parseFunctionDefinition()
        case .returnKeyword:
            return parseReturn()
        case .ifKeyword:
            return parseIfElse()
        case .eof:
            return nil
        default:
            fatalError("Unexpected token \(currentToken.tokenKind) \(currentToken.text)")
        }
        return nil
    }

    func parseExpression() -> Node? {
        guard let lhs = parsePrimary() else {
            return nil
        }
        return parseBinaryOperatorRHS(expressionPrecedence: 0, lhs: lhs)
    }

    private func parseReturn() -> Node {
        guard case .returnKeyword = currentToken.tokenKind else {
            fatalError("returnKeyword is expected but received \(currentToken.tokenKind)")
        }
        read() // eat return
        if let expression = parseExpression() {
            return ReturnNode(body: expression)
        } else {
            // return nothing
            return ReturnNode(body: nil)
        }
    }

    private func parseParen() -> Node? {
        read() // eat (
        guard let v = parseExpression() else {
            return nil
        }

        guard case .rightParen = currentToken.tokenKind else {
                fatalError("expected ')'")
        }
        read() // eat )

        return v
    }

    private func parseTopLevelExpression() -> Node? {
        if let expression = parseExpression() {
            // we treat top level expressions as anonymous functions
            let anonymousPrototype = FunctionNode(name: "main", arguments: [], returnType: .int, body: expression)
            return anonymousPrototype
        }
        return nil
    }
}

private extension BinaryExpressionNode.Operator {
    var precedence: Int {
        switch self {
        case .addition, .subtraction: return 20
        case .multication, .division: return 40
        case .lessThan:
            fatalError("Not Implemented")
        }
    }
}
