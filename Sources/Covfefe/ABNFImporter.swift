//
//  File.swift
//  
//
//  Created by Palle Klewitz on 23.05.20.
//  Copyright (c) 2020 Palle Klewitz
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

let abnfGrammar: Grammar = {
    let abnfStr = """
    rule-list = [whitespace], [{rule, whitespace}], rule, [eof-comment] | [whitespace];

    rule = init-rule | incremental-alternation;
    init-rule = [whitespace], nonterminal, [whitespace], '=', [whitespace], alternation;
    incremental-alternation = [whitespace], nonterminal, [whitespace], '=', '/', [whitespace], alternation;

    alternation = alternation, [whitespace], "/", [whitespace], concatenation | concatenation;
    concatenation = concatenation, whitespace, atom | atom;
    atom = optional | sequence-group | repetition | nonterminal | terminal;
    optional = "[", [whitespace], alternation, [whitespace], "]";
    sequence-group = "(", [whitespace], alternation, [whitespace], ")";
    repetition = variable-repetition | specific-repetition;
    variable-repetition = (closed-range | partial-range-to | partial-range-from | unlimited-range), atom;
    specific-repetition = integer-literal, atom;

    closed-range = integer-literal, '*', integer-literal;
    partial-range-to = '*', integer-literal;
    partial-range-from = integer-literal, '*';
    unlimited-range = '*';

    nonterminal = ("a" ... "z" | "A" ... "Z" | "_" | "-"), {"a" ... "z" | "A" ... "Z" | "0" ... "9" | "_" | "-"};
    terminal = string-literal | charcode-literal | charcode-range-literal;

    string-literal = '"', [{string-content}], '"';
    charcode-literal = "%", "x", hex-int;
    charcode-range-literal = "%", "x", hex-int, "-", hex-int;

    integer-literal = {digit};
    hex-int = {hex-digit};
    hex-digit = "0" ... "9" | "a" ... "f" | "A" ... "F";
    digit = "0" ... "9";
    whitespace = {" " | "\\t" | "\\n" | "\\r", "\\n" | comment};
    comment = ";", [{any-except-linebreak}], "\\n";
    eof-comment = ";", [{any-except-linebreak}];
    string-content = "\\u{01}" ... "\\u{21}" | "\\u{23}" ... "\\u{5B}" | "\\u{5D}" ... "\\u{FFFF}" | escape-sequence;
    escape-sequence = "\\\\", '"';
    any-except-linebreak = "\\u{01}" ... "\\u{09}" | "\\u{0B}" ... "\\u{0C}" | "\\u{0E}" ... "\\u{FFFF}";
    """
    
    return try! Grammar(ebnf: abnfStr, start: "rule-list")
}()


/// Errors specific to the import of ABNF grammars
public enum ABNFImportError: Error {
    /// The grammar contains a range expression with a lower bound higher than the upper bound
    case invalidRange(line: Int, column: Int)
    case invalidCharcode(line: Int, column: Int)
}

public extension Grammar {
    private static let coreRules: [Production] = [
        Production(pattern: NonTerminal(name: "ALPHA"), production: [.terminal(Terminal(range: "A" ... "Z"))]),
        Production(pattern: NonTerminal(name: "ALPHA"), production: [.terminal(Terminal(range: "a" ... "z"))]),
        Production(pattern: NonTerminal(name: "DIGIT"), production: [.terminal(Terminal(range: "0" ... "9"))]),
        Production(pattern: NonTerminal(name: "HEXDIG"), production: [.terminal(Terminal(range: "0" ... "9"))]),
        Production(pattern: NonTerminal(name: "HEXDIG"), production: [.terminal(Terminal(range: "a" ... "f"))]),
        Production(pattern: NonTerminal(name: "HEXDIG"), production: [.terminal(Terminal(range: "A" ... "F"))]),
        Production(pattern: NonTerminal(name: "DQUOTE"), production: [.terminal("\"")]),
        Production(pattern: NonTerminal(name: "SP"), production: [.terminal(" ")]),
        Production(pattern: NonTerminal(name: "HTAB"), production: [.terminal("\u{09}")]),
        Production(pattern: NonTerminal(name: "WSP"), production: [.nonTerminal("SP")]),
        Production(pattern: NonTerminal(name: "WSP"), production: [.nonTerminal("HTAB")]),
        Production(pattern: NonTerminal(name: "LWSP"), production: [.nonTerminal("WSP")]),
        Production(pattern: NonTerminal(name: "LWSP"), production: [.nonTerminal("CRLF"), .nonTerminal("WSP")]),
        Production(pattern: NonTerminal(name: "VCHAR"), production: [.terminal(Terminal(range: "\u{21}" ... "\u{7e}"))]),
        Production(pattern: NonTerminal(name: "CHAR"), production: [.terminal(Terminal(range: "\u{01}" ... "\u{7e}"))]),
        Production(pattern: NonTerminal(name: "OCTET"), production: [.terminal(Terminal(range: "\u{00}" ... "\u{ff}"))]),
        Production(pattern: NonTerminal(name: "CTL"), production: [.terminal(Terminal(range: "\u{00}" ... "\u{1f}"))]),
        Production(pattern: NonTerminal(name: "CTL"), production: [.terminal("\u{7f}")]),
        Production(pattern: NonTerminal(name: "CR"), production: [.terminal("\u{0d}")]),
        Production(pattern: NonTerminal(name: "LF"), production: [.terminal("\u{0a}")]),
        Production(pattern: NonTerminal(name: "CRLF"), production: [.nonTerminal("CR"), .nonTerminal("LF")]),
        Production(pattern: NonTerminal(name: "BIT"), production: [.terminal("0"), .terminal("1")]),
    ]
    
    init(abnf: String, start: String) throws {
        // Clean up string so parser has easier job
        let abnf = abnf
            .replacingOccurrences(of: #";[^\n]*\n"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"\n\s*\n"#, with: "\n", options: .regularExpression)
        
        func flatten(parseTree: ParseTree, nodeName: String) -> [ParseTree] {
            switch parseTree {
            case .node(key: NonTerminal(name: nodeName), children: let children):
                return children.flatMap {
                    flatten(parseTree: $0, nodeName: nodeName)
                }
            default:
                return [parseTree]
            }
        }
        
        func parse(nonTerminal: ParseTree) -> NonTerminal {
            let nt = nonTerminal.leafs.map {abnf[$0]}.joined()
            return NonTerminal(name: nt)
        }
        
        func parse(stringLiteral: ParseTree) -> String {
            guard case .node(key: "string-literal", children: let children) = stringLiteral else {
                fatalError("Invalid parse tree")
            }
            return children.dropFirst().dropLast().flatMap {$0.leafs}.map {abnf[$0]}.joined()
        }
        
        func parse(hexInt: ParseTree) throws -> Character {
            let hexDigits = hexInt.leafs.map {abnf[$0]}.joined()
            
            guard let scalar = UInt32(hexDigits, radix: 16), let unichar = UnicodeScalar(scalar) else {
                throw ABNFImportError.invalidRange(
                    line: abnf[...hexInt.leafs[0].lowerBound].filter {$0.isNewline}.count,
                    column: abnf.distance(
                        from: abnf[...hexInt.leafs[0].lowerBound].lastIndex(where: {$0.isNewline}) ?? abnf.startIndex,
                        to: hexInt.leafs[0].lowerBound
                    )
                )
            }
            return Character(unichar)
        }
        
        func parse(charcodeLiteral: ParseTree) throws -> Character {
            guard case .node(key: "charcode-literal", children: let children) = charcodeLiteral, children.count == 3 else {
                fatalError("Invalid parse tree")
            }
            return try parse(hexInt: children[2])
        }
        
        func parse(charcodeRangeLiteral: ParseTree) throws -> Terminal {
            guard case .node(key: "charcode-range-literal", children: let children) = charcodeRangeLiteral, children.count == 5 else {
                fatalError("Invalid parse tree")
            }
            let lowerBound = try parse(hexInt: children[2])
            let upperBound = try parse(hexInt: children[4])
            return Terminal(range: lowerBound ... upperBound)
        }
        
        func parse(terminal: ParseTree) throws -> Terminal {
            guard case .node(key: "terminal", children: let children) = terminal, children.count == 1, let firstChild = children.first else {
                fatalError("Invalid parse tree")
            }
            switch firstChild {
            case .node(key: "charcode-literal", children: _):
                return try Terminal(string: String(parse(charcodeLiteral: firstChild)))
                
            case .node(key: "charcode-range-literal", children: _):
                return try parse(charcodeRangeLiteral: firstChild)
                
            case .node(key: "string-literal", children: _):
                return Terminal(string: parse(stringLiteral: firstChild))
                
            default:
                fatalError("Invalid parse tree")
            }
        }
        
        func parse(optional: ParseTree, alternationIndex: Int, concatenationIndex: Int, ruleName: String) throws -> ([Symbol], Set<Production>) {
            guard case .node(key: "optional", children: let children) = optional, children.count == 3 else {
                fatalError("Invalid parse tree")
            }
            let subRuleName = "\(ruleName)-a\(alternationIndex)-c\(concatenationIndex)"
            let (subAlternations, additionalRules) = try parse(alternation: children[1], ruleName: subRuleName)
            return (
                [.nonTerminal(NonTerminal(name: subRuleName))],
                additionalRules
                    .union(subAlternations.map {
                        Production(pattern: NonTerminal(name: subRuleName), production: $0)
                    })
                    .union([
                        Production(pattern: NonTerminal(name: subRuleName), production: [])
                    ])
            )
        }
        
        func parse(sequenceGroup: ParseTree, alternationIndex: Int, concatenationIndex: Int, ruleName: String) throws -> ([Symbol], Set<Production>) {
            guard case .node(key: "sequence-group", children: let children) = sequenceGroup, children.count == 3 else {
                fatalError("Invalid parse tree")
            }
            let subRuleName = "\(ruleName)-a\(alternationIndex)-c\(concatenationIndex)"
            let (subAlternations, additionalRules) = try parse(alternation: children[1], ruleName: subRuleName)
            return (
                [.nonTerminal(NonTerminal(name: subRuleName))],
                additionalRules
                    .union(subAlternations.map {
                        Production(pattern: NonTerminal(name: subRuleName), production: $0)
                    })
            )
        }
        
        func parse(integerLiteral: ParseTree) -> Int {
            guard case .node(key: "integer-literal", children: _) = integerLiteral else {
                fatalError("Invalid parse tree")
            }
            guard let integer = Int(integerLiteral.leafs.map {abnf[$0]}.joined()) else {
                fatalError("Invalid parse tree")
            }
            return integer
        }
        
        func parse(range: ParseTree) throws -> (Int?, Int?) {
            switch range {
            case .node(key: "closed-range", children: let children):
                let (lowerBound, upperBound) = (parse(integerLiteral: children[0]), parse(integerLiteral: children[2]))
                if lowerBound > upperBound {
                    throw ABNFImportError.invalidRange(
                        line: abnf[...range.leafs[0].lowerBound].filter {$0.isNewline}.count,
                        column: abnf.distance(
                            from: abnf[...range.leafs[0].lowerBound].lastIndex(where: {$0.isNewline}) ?? abnf.startIndex,
                            to: range.leafs[0].lowerBound
                        )
                    )
                }
                return (lowerBound, upperBound)
            case .node(key: "partial-range-to", children: let children):
                return (nil, parse(integerLiteral: children[1]))
            case .node(key: "partial-range-from", children: let children):
                return (parse(integerLiteral: children[0]), nil)
            case .node(key: "unlimited-range", children: _):
                return (nil, nil)
            default:
                fatalError("Invalid parse tree")
            }
        }
        
        func parse(variableRepetition: ParseTree, alternationIndex: Int, concatenationIndex: Int, ruleName: String) throws -> ([Symbol], Set<Production>) {
            guard case .node(key: "variable-repetition", children: let children) = variableRepetition, let range = children.first, let atom = children.last else {
                fatalError("Invalid parse tree")
            }
            
            let subRuleName = "\(ruleName)-a\(alternationIndex)-c\(concatenationIndex)"
            let (subrule, additionalRules) = try parse(atom: atom, alternationIndex: alternationIndex, concatenationIndex: concatenationIndex, ruleName: subRuleName)
            
            switch try parse(range: range) {
            case (.none, .none):
                let repeatingRule = [
                    Production(pattern: NonTerminal(name: subRuleName), production: []),
                    Production(pattern: NonTerminal(name: subRuleName), production: [.nonTerminal(NonTerminal(name: subRuleName))] + subrule),
                ]
                return (
                    [.nonTerminal(NonTerminal(name: subRuleName))],
                    additionalRules.union(repeatingRule)
                )
                
            case (.some(let lowerBound), .none):
                let repeatingRule = [
                    Production(pattern: NonTerminal(name: subRuleName), production: Array(repeatElement(subrule, count: lowerBound).joined())),
                    Production(pattern: NonTerminal(name: subRuleName), production: [.nonTerminal(NonTerminal(name: subRuleName))] + subrule),
                ]
                return (
                    [.nonTerminal(NonTerminal(name: subRuleName))],
                    additionalRules.union(repeatingRule)
                )
                
            case (.none, .some(let upperBound)):
                let optionalRange = repeatElement(NonTerminal(name: subRuleName), count: upperBound)
                
                let optionalRule = [
                    Production(pattern: NonTerminal(name: subRuleName), production: []),
                    Production(pattern: NonTerminal(name: subRuleName), production: subrule),
                ]
                return (
                    optionalRange.map(Symbol.nonTerminal),
                    additionalRules.union(optionalRule)
                )
                
            case (.some(let lowerBound), .some(let upperBound)):
                let baseRepetitions = Array(repeatElement(subrule, count: lowerBound).joined())
                let optionalRange = repeatElement(NonTerminal(name: subRuleName), count: upperBound - lowerBound)
                
                let optionalRule = [
                    Production(pattern: NonTerminal(name: subRuleName), production: []),
                    Production(pattern: NonTerminal(name: subRuleName), production: subrule),
                ]
                return (
                    baseRepetitions + optionalRange.map(Symbol.nonTerminal),
                    additionalRules.union(optionalRule)
                )
            }
        }
        
        func parse(specificRepetition: ParseTree, alternationIndex: Int, concatenationIndex: Int, ruleName: String) throws -> ([Symbol], Set<Production>) {
            guard case .node(key: "specific-repetition", children: let children) = specificRepetition, let countLiteral = children.first, let atom = children.last else {
                fatalError("Invalid parse tree")
            }
            let count = parse(integerLiteral: countLiteral)
            let (subrule, additionalRules) = try parse(atom: atom, alternationIndex: alternationIndex, concatenationIndex: concatenationIndex, ruleName: ruleName)
            return (
                Array(repeatElement(subrule, count: count).joined()),
                additionalRules
            )
        }
        
        func parse(repetition: ParseTree, alternationIndex: Int, concatenationIndex: Int, ruleName: String) throws -> ([Symbol], Set<Production>) {
            guard case .node(key: "repetition", children: let children) = repetition, children.count == 1, let firstChild = children.first else {
                fatalError("Invalid parse tree")
            }
            switch firstChild {
            case .node(key: "variable-repetition", children: _):
                return try parse(variableRepetition: firstChild, alternationIndex: alternationIndex, concatenationIndex: concatenationIndex, ruleName: ruleName)
                
            case .node(key: "specific-repetition", children: _):
                return try parse(specificRepetition: firstChild, alternationIndex: alternationIndex, concatenationIndex: concatenationIndex, ruleName: ruleName)
                
            default:
                fatalError("Invalid parse tree")
            }
        }
        
        func parse(atom: ParseTree, alternationIndex: Int, concatenationIndex: Int, ruleName: String) throws -> ([Symbol], Set<Production>) {
            guard case .node(key: "atom", children: let children) = atom, children.count == 1, let firstChild = children.first else {
                fatalError("Invalid parse tree")
            }
            switch firstChild {
            case .node(key: "optional", children: _):
                return try parse(optional: firstChild, alternationIndex: alternationIndex, concatenationIndex: concatenationIndex, ruleName: ruleName)
                
            case .node(key: "sequence-group", children: _):
                return try parse(sequenceGroup: firstChild, alternationIndex: alternationIndex, concatenationIndex: concatenationIndex, ruleName: ruleName)

            case .node(key: "repetition", children: _):
                return try parse(repetition: firstChild, alternationIndex: alternationIndex, concatenationIndex: concatenationIndex, ruleName: ruleName)

            case .node(key: "nonterminal", children: _):
                return ([Symbol.nonTerminal(parse(nonTerminal: firstChild))], [])

            case .node(key: "terminal", children: _):
                return try ([Symbol.terminal(parse(terminal: firstChild))], [])
                
            default:
                fatalError("Invalid parse tree")
            }
        }
        
        func parse(concatenation: ParseTree, atIndex index: Int, ruleName: String) throws -> ([Symbol], Set<Production>) {
            let atoms = flatten(parseTree: concatenation, nodeName: "concatenation")
            return try atoms.enumerated()
                .map {try parse(atom: $1, alternationIndex: index, concatenationIndex: $0, ruleName: ruleName)}
                .reduce(into: ([], [])) { acc, atom in
                    acc.0 += atom.0
                    acc.1.formUnion(atom.1)
                }
        }
        
        func parse(alternation: ParseTree, ruleName: String) throws -> ([[Symbol]], Set<Production>) {
            let concatenations = flatten(parseTree: alternation, nodeName: "alternation")
                .filter {$0.root != nil}
            return try concatenations.enumerated()
                .map {try parse(concatenation: $1, atIndex: $0, ruleName: ruleName)}
                .reduce(into: ([], [])) { acc, cat in
                    acc.0.append(cat.0)
                    acc.1.formUnion(cat.1)
                }
        }
        
        func parse(initRule rule: ParseTree) throws -> ([Production], Set<Production>) {
            guard case .node(key: "init-rule", children: let children) = rule, children.count == 3 else {
                fatalError("Invalid parse tree")
            }
            let pattern = parse(nonTerminal: children[0])
            let (alternations, utilityProds) = try parse(alternation: children[2], ruleName: pattern.name)
            return (
                alternations.map {
                    Production(pattern: pattern, production: $0)
                },
                utilityProds
            )
        }
        
        func parse(incrementalRule rule: ParseTree) throws -> ([Production], Set<Production>) {
            guard case .node(key: "incremental-alternation", children: let children) = rule, children.count == 4 else {
                fatalError("Invalid parse tree")
            }
            let pattern = parse(nonTerminal: children[0])
            let (alternations, utilityProds) = try parse(alternation: children[3], ruleName: pattern.name)
            return (
                alternations.map {
                    Production(pattern: pattern, production: $0)
                },
                utilityProds
            )
        }
        
        func parse(rule: ParseTree) throws -> ([Production], Set<Production>) {
            guard case .node(key: "rule", children: let children) = rule, let firstChild = children.first, children.count == 1 else {
                fatalError("Invalid parse tree")
            }
            switch firstChild {
            case .node(key: "init-rule", children: _):
                return try parse(initRule: firstChild)
            case .node(key: "incremental-alternation", children: _):
                return try parse(incrementalRule: firstChild)
            default:
                fatalError("Invalid parse tree")
            }
        }
        
        let parser = EarleyParser(grammar: abnfGrammar)
        guard let tree = try parser.syntaxTree(for: abnf).filter({$0.name != "whitespace"}) else {
            self = Grammar(productions: [], start: NonTerminal(name: start))
            return
        }
        
        let ruleExpressions = tree.allNodes(where: {$0.name == "rule"})
        let allProductions = try ruleExpressions.map(parse(rule:))
        let (visibleRules, hiddenRules): ([[Production]], [Set<Production>]) = unzip(allProductions)
        
        self = Grammar(
            productions: Grammar.coreRules + Array(visibleRules.joined()) + Array(hiddenRules.joined()),
            start: NonTerminal(name: start),
            utilityNonTerminals: Set(hiddenRules.joined().map {$0.pattern})
        )
    }
}
