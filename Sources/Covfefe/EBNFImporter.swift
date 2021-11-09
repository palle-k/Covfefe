//
//  EBNFImporter.swift
//  Covfefe
//
//  Created by Palle Klewitz on 14.08.17.
//  Copyright (c) 2017 Palle Klewitz
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

/// A grammar describing the Backus-Naur form
var ebnfGrammar: Grammar {
	return Grammar(start: "syntax") {
		"syntax" --> n("optional-whitespace") <|> n("newlines") <|> n("rule") <|> n("rule") <+> n("newlines") <|> n("syntax") <+> n("newlines") <+> n("rule") <+> (n("newlines") <|> [[]])
		"rule" --> n("optional-whitespace") <+> n("rule-name-container") <+> n("optional-whitespace") <+> n("assignment-operator") <+> n("optional-whitespace") <+> n("expression") <+> n("optional-whitespace") <+> t(";") <+> n("optional-whitespace")
		
		"optional-whitespace" --> [[]] <|> n("whitespace") <+> [n("optional-whitespace")]
		"whitespace" --> t(.whitespacesAndNewlines) <|> n("comment")
		"newlines" --> t("\n") <|> t("\n") <+> n("optional-whitespace") <+> n("newlines")
		
		"comment" --> t("(") <+> t("*") <+> n("comment-content") <+> t("*") <+> t(")") <|> t("(") <+> t("*") <+> t("*") <+> t("*") <+> t(")")
		"comment-content" --> n("comment-content") <+> n("comment-content-char") <|> [[]]
		// a comment cannot contain a * followed by a ) or a ( followed by a *
		try! "comment-content-char" --> re("[^*(]") <|> n("comment-asterisk") <+> re("[^)]") <|> n("comment-open-parenthesis") <+> re("[^*]") <|> n("comment")
		"comment-asterisk" --> n("comment-asterisk") <+> t("*") <|> t("*")
		"comment-open-parenthesis" --> n("comment-open-parenthesis") <+> t("(") <|> t("(")
		
		"assignment-operator" --> t("=")
		
		"rule-name-container" --> n("delimiting-rule-name-char") <+> n("rule-name") <+> n("delimiting-rule-name-char") <|> n("delimiting-rule-name-char")
		"rule-name" --> n("rule-name") <+> n("rule-name-char") <|> t()
		"rule-name-char" --> n("delimiting-rule-name-char") <|> n("whitespace")
		try! "delimiting-rule-name-char" --> re("[a-zA-Z0-9-_]")
		
		"expression" --> n("concatenation") <|> n("alternation")
		"alternation" --> n("expression") <+> n("optional-whitespace") <+> t("|") <+> n("optional-whitespace") <+> n("concatenation")
		"concatenation" --> n("expression-element") <|> n("concatenation") <+> n("optional-whitespace") <+> t(",") <+> n("optional-whitespace") <+> n("expression-element")
		"expression-element" --> n("literal") <|> n("rule-name-container") <|> n("expression-group") <|> n("expression-repetition") <|> n("expression-optional") <|> n("expression-multiply")
		
		"expression-group" --> t("(") <+> n("optional-whitespace") <+> n("expression") <+> n("optional-whitespace") <+> t(")")
		"expression-repetition" --> t("{") <+> n("optional-whitespace") <+> n("expression") <+> n("optional-whitespace") <+> t("}")
		"expression-optional" --> t("[") <+> n("optional-whitespace") <+> n("expression") <+> n("optional-whitespace") <+> t("]")
		"expression-multiply" --> n("number") <+> n("optional-whitespace") <+> t("*") <+> n("optional-whitespace") <+> n("expression-element")
		
		"literal" --> t("'") <+> n("string-1") <+> t("'") <|> t("\"") <+> n("string-2") <+> t("\"") <|> n("range-literal")
		"string-1" --> n("string-1") <+> n("string-1-char") <|> [[]]
		"string-2" --> n("string-2") <+> n("string-2-char") <|> [[]]
		
		"range-literal" --> n("single-char-literal") <+> n("optional-whitespace") <+> t(".") <+> t(".") <+> t(".") <+> n("optional-whitespace") <+> n("single-char-literal")
		"single-char-literal" --> t("'") <+> n("string-1-char") <+> t("'") <|> t("\"") <+> n("string-2-char") <+> t("\"")
		
		// no ', \, \r or \n
		try! "string-1-char" --> re("[^'\\\\\r\n]") <|> n("string-escaped-char") <|> n("escaped-single-quote")
		try! "string-2-char" --> re("[^\"\\\\\r\n]") <|> n("string-escaped-char") <|> n("escaped-double-quote")
		
		try! "digit" --> re("[0-9]")
		"number" --> n("digit") <|> n("number") <+> n("digit")
		
		"string-escaped-char" --> n("unicode-scalar") <|> n("carriage-return") <|> n("line-feed") <|> n("tab-char") <|> n("backslash")
		"unicode-scalar" --> t("\\") <+> t("u") <+> t("{") <+>  n("unicode-scalar-digits") <+> t("}")
		"unicode-scalar-digits" --> [n("hex-digit")] <+> (n("hex-digit") <|> [[]]) <+> (n("hex-digit") <|> [[]]) <+> (n("hex-digit") <|> [[]]) <+> (n("hex-digit") <|> [[]]) <+> (n("hex-digit") <|> [[]]) <+> (n("hex-digit") <|> [[]]) <+> (n("hex-digit") <|> [[]])
		try! "hex-digit" --> re("[0-9a-fA-F]")
		
		"carriage-return" --> t("\\") <+> t("r")
		"line-feed" --> t("\\") <+> t("n")
		"tab-char" --> t("\\") <+> t("t")
		"backslash" --> t("\\") <+> t("\\")
		"escaped-single-quote" --> t("\\") <+> t("'")
		"escaped-double-quote" --> t("\\") <+> t("\"")
	}	
}

public extension Grammar {
	
	/// Creates a new grammar from a specification in Extended Backus-Naur Form (EBNF)
	///
	/// 	pattern1 = alternative1 | alternative2;
	///  	pattern2 = 'con', 'catenation';
	///
	/// - Parameters:
	///   - bnfString: String describing the grammar in EBNF
	///   - start: Start non-terminal
	init(ebnf ebnfString: String, start: String) throws {
		let grammar = ebnfGrammar
		let parser = EarleyParser(grammar: grammar)
		let syntaxTree = try parser
			.syntaxTree(for: ebnfString)
			.explode{["expression"].contains($0)}
			.first!
			.filter{!["optional-whitespace", "newlines"].contains($0)}!
		
		let ruleDeclarations = syntaxTree.allNodes(where: {$0.name == "rule"})
		
		func ruleName(from container: SyntaxTree<NonTerminal, Range<String.Index>>) -> String {
			return container.leafs
				.reduce("") { partialResult, range -> String in
					partialResult.appending(ebnfString[range])
			}
		}
		
		func character(fromCharacterExpression characterExpression: ParseTree) throws -> Character {
			guard let child = characterExpression.children?.first else {
				fatalError()
			}
			switch child {
			case .leaf(let range):
				return ebnfString[range.lowerBound]
				
			case .node(key: "string-escaped-char", children: let children):
				guard let child = children.first else {
					fatalError()
				}
				switch child {
				case .leaf:
					fatalError()
					
				case .node(key: "unicode-scalar", children: let children):
					let hexString: String = children.dropFirst(3).dropLast().flatMap {$0.leafs}.map {ebnfString[$0]}.joined()
					// Grammar guarantees that hexString is always a valid hex integer literal
					let charValue = Int(hexString, radix: 16)!
					guard let scalar = UnicodeScalar(charValue) else {
						throw LiteralParsingError.invalidUnicodeScalar(charValue)
					}
					return Character(scalar)
					
				case .node(key: "carriage-return", children: _):
					return "\r"
					
				case .node(key: "line-feed", children: _):
					return "\n"
					
				case .node(key: "tab-char", children: _):
					return "\t"
					
				case .node(key: "backslash", children: _):
					return "\\"
					
				default:
					fatalError()
				}
				
			case .node(key: "escaped-single-quote", children: _):
				return "'"
				
			case .node(key: "escaped-double-quote", children: _):
				return "\""
				
			default:
				fatalError()
			}
		}
		
		func string(fromStringExpression stringExpression: ParseTree, knownString: String = "") throws -> String {
			if let children = stringExpression.children, children.count == 2 {
				let char = try character(fromCharacterExpression: children[1])
				return try string(fromStringExpression: children[0], knownString: "\(char)\(knownString)")
			} else {
				return knownString
			}
		}
		
		func terminal(fromLiteral literal: ParseTree) throws -> Terminal {
			guard let children = literal.children else {
				fatalError()
			}
			if children.count == 3 {
				let stringNode = children[1]
				return try Terminal(string: string(fromStringExpression: stringNode))
			} else if children.count == 1 {
				let rangeExpression = children[0]
				guard rangeExpression.root == "range-literal" else {
					fatalError()
				}
				guard let children = rangeExpression.children, children.count == 5 else {
					fatalError()
				}
				let lowerBound = try character(fromCharacterExpression: children[0].children![1])
				let upperBound = try character(fromCharacterExpression: children[4].children![1])
				
				guard lowerBound <= upperBound else {
					throw LiteralParsingError.invalidRange(lowerBound: lowerBound, upperBound: upperBound, description: "lowerBound must be less than or equal to upperBound")
				}
				
				return Terminal(range: lowerBound ... upperBound)
			}
			
			fatalError()
		}
		
		func makeProductions(from expression: SyntaxTree<NonTerminal, Range<String.Index>>, named name: String) throws -> (productions: [Production], additionalRules: [Production]) {
			guard let type = expression.root?.name else {
				return ([], [])
			}
			guard let children = expression.children else {
				return ([], [])
			}
			switch type {
			case "alternation":
				let (lhs, lhsAdd) = try makeProductions(from: children[0], named: "\(name)-a0")
				let (rhs, rhsAdd) = try makeProductions(from: children[2], named: "\(name)-a1")
				return ((lhs + rhs).map {Production(pattern: NonTerminal(name: name), production: $0.production)}, lhsAdd + rhsAdd)
				
			case "concatenation":
				if children.count == 3 {
					let (lhsProductions, lhsAdd) = try makeProductions(from: children[0], named: "\(name)-c0")
					let (rhsProductions, rhsAdd) = try makeProductions(from: children[2], named: "\(name)-c1")
					
					return (crossProduct(lhsProductions, rhsProductions).map { arg -> Production in
						let (lhs, rhs) = arg
						return Production(pattern: NonTerminal(name: name), production: lhs.production + rhs.production)
					}, lhsAdd + rhsAdd)
				} else if children.count == 1 {
					return try makeProductions(from: children[0], named: name)
				} else {
					fatalError()
				}
				
			case "expression-element":
				guard children.count == 1 else {
					return ([], [])
				}
				switch children[0].root!.name {
				case "literal":
					let t = try terminal(fromLiteral: children[0])
					if t.isEmpty {
						return ([Production(pattern: NonTerminal(name: name), production: [])], [])
					} else {
						return ([Production(pattern: NonTerminal(name: name), production: [.terminal(t)])], [])
					}
					
				case "rule-name-container":
					let nonTerminalName = ruleName(from: children[0])
					return ([Production(pattern: NonTerminal(name: name), production: [n(nonTerminalName)])], [])
					
				case "expression-group":
					guard let group = children[0].children else {
						fatalError()
					}
					assert(group.count == 3)
					return try makeProductions(from: group[1], named: name)
					
				case "expression-repetition":
					guard let group = children[0].children else {
						fatalError()
					}
					assert(group.count == 3)
					let subruleName = "\(name)-r"
					let (subRules, additionalRules) = try makeProductions(from: group[1], named: subruleName)
					let repetitionRules = subRules.map { rule in
						Production(pattern: NonTerminal(name: subruleName), production: [n(subruleName)] + rule.production)
					}
					return ([Production(pattern: NonTerminal(name: name), production: [n(subruleName)])], additionalRules + subRules + repetitionRules)
					
				case "expression-optional":
					guard let group = children[0].children else {
						fatalError()
					}
					assert(group.count == 3)
					let subruleName = "\(name)-o"
					let (productions, additionalProductions) = try makeProductions(from: group[1], named: subruleName)
					let optionalProductions = productions.map {
						Production(pattern: $0.pattern, production: [])
					}
					let subproduction = Production(pattern: NonTerminal(name: name), production: [n(subruleName)])
					return ([subproduction], additionalProductions + productions + optionalProductions)
					
				case "expression-multiply":
					guard let group = children[0].children else {
						fatalError()
					}
					let multiplicityExpression = group[0].leafs
					let multiplicityRange = multiplicityExpression.first!.lowerBound ..< multiplicityExpression.last!.upperBound
					let multiplicity = Int(ebnfString[multiplicityRange])!
					
					let subruleName = "\(name)-m"
					let (subrules, additionalExpressions) = try makeProductions(from: group[2], named: subruleName)
					
					let repeatedSubrules = repeatElement(subrules, count: multiplicity).reduce([]) { (acc, subrules) -> [Production] in
						if acc.isEmpty {
							return subrules.map { rule in
								return Production(pattern: NonTerminal(name: name), production: rule.production)
							}
						} else {
							return crossProduct(acc, subrules).map { arg in
								let (lhs, rhs) = arg
								return Production(pattern: NonTerminal(name: name), production: lhs.production + rhs.production)
							}
						}
					}
					return (repeatedSubrules, additionalExpressions)
					
				default:
					fatalError()
				}
				
			default:
				fatalError()
			}
		}
		
		let (productions, helperRules): ([Production], [Production]) = try ruleDeclarations.reduce(into: ([], [])) { acc, ruleDeclaration in
			guard let children = ruleDeclaration.children, children.count == 4 else {
				return
			}
			let name = ruleName(from: children[0])
			let (productions, additionalRules) = try makeProductions(from: children[2], named: name)
			acc.0.append(contentsOf: productions)
			acc.1.append(contentsOf: additionalRules)
		}
		
		if (productions + helperRules).contains(where: { (production: Production) -> Bool in
			production.generatedNonTerminals.contains("EOL")
		}) && !(productions + helperRules).contains(where: { (production: Production) -> Bool in
			production.pattern == "EOL"
		}) {
			self.init(productions: productions + helperRules + ("EOL" --> t("\n")), start: NonTerminal(name: start), utilityNonTerminals: helperRules.map {$0.pattern}.collect(Set.init))
		} else {
			self.init(productions: productions + helperRules, start: NonTerminal(name: start), utilityNonTerminals: helperRules.map {$0.pattern}.collect(Set.init))
		}
		
	}
}
