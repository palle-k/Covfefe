//
//  BNFImporter.swift
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
var bnfGrammar: Grammar {
	
	let syntax = "syntax" --> n("optional-whitespace") <|> n("newlines") <|> n("rule") <|> n("rule") <+> n("newlines") <|> n("syntax") <+> n("newlines") <+> n("rule") <+> (n("newlines") <|> [[]])
	let rule = "rule" --> n("optional-whitespace") <+> n("rule-name-container") <+> n("optional-whitespace") <+> n("assignment-operator") <+> n("optional-whitespace") <+> n("expression") <+> n("optional-whitespace")
	
	let optionalWhitespace = "optional-whitespace" --> [[]] <|> n("whitespace") <+> [n("optional-whitespace")]
	let whitespace = "whitespace" --> SymbolSet.whitespace <|> n("comment")
	let newlines = "newlines" --> t("\n") <|> t("\n") <+> n("optional-whitespace") <+> n("newlines")
	
	let comment = "comment" --> t("(") <+> t("*") <+> n("comment-content") <+> t("*") <+> t(")") <|> t("(") <+> t("*") <+> t("*") <+> t("*") <+> t(")")
	let commentContent = "comment-content" --> n("comment-content") <+> n("comment-content-char") <|> [[]]
	// a comment cannot contain a * followed by a ) or a ( followed by a *
	let commentContentChar = try! "comment-content-char" --> rt("[^*(]") <|> n("comment-asterisk") <+> rt("[^)]") <|> n("comment-open-parenthesis") <+> rt("[^*]") <|> n("comment")
	let commentAsterisk = "comment-asterisk" --> n("comment-asterisk") <+> t("*") <|> t("*")
	let commentOpenParenthesis = "comment-open-parenthesis" --> n("comment-open-parenthesis") <+> t("(") <|> t("(")
	
	let assignmentOperator = "assignment-operator" --> t(":") <+> t(":") <+> t("=")
	
	let ruleNameContainer = "rule-name-container" --> t("<") <+> n("rule-name") <+> t(">")
	let ruleName = "rule-name" --> n("rule-name") <+> n("rule-name-char") <|> [[]]
	let ruleNameChar = try! "rule-name-char" --> rt("[a-zA-Z0-9-_]")
	
	let expression = "expression" --> n("concatenation") <|> n("alternation")
	let alternation = "alternation" --> n("expression") <+> n("optional-whitespace") <+> t("|") <+> n("optional-whitespace") <+> n("concatenation")
	let concatenation = "concatenation" --> n("expression-element") <|> n("concatenation") <+> n("optional-whitespace") <+> n("expression-element")
	let expressionElement = "expression-element" --> n("literal") <|> n("rule-name-container") <|> n("expression-group") <|> n("expression-repetition") <|> n("expression-optional")
	let expressionGroup = "expression-group" --> t("(") <+> n("optional-whitespace") <+> n("expression") <+> n("optional-whitespace") <+> t(")")
	let expressionRepetition = "expression-repetition" --> t("{") <+> n("optional-whitespace") <+> n("expression") <+> n("optional-whitespace") <+> t("}")
	let expressionOptional = "expression-optional" --> t("[") <+> n("optional-whitespace") <+> n("expression") <+> n("optional-whitespace") <+> t("]")
	let literal = "literal" --> t("'") <+> n("string-1") <+> t("'") <|> t("\"") <+> n("string-2") <+> t("\"") <|> n("range-literal")
	let string1 = "string-1" --> n("string-1") <+> n("string-1-char") <|> [[]]
	let string2 = "string-2" --> n("string-2") <+> n("string-2-char") <|> [[]]
	
	let rangeLiteral = "range-literal" --> n("single-char-literal") <+> n("optional-whitespace") <+> t(".") <+> t(".") <+> t(".") <+> n("optional-whitespace") <+> n("single-char-literal")
	let singleCharLiteral = "single-char-literal" --> t("'") <+> n("string-1-char") <+> t("'") <|> t("\"") <+> n("string-2-char") <+> t("\"")
	
	// no ', \, \r or \n
	let string1char = try! "string-1-char" --> rt("[^'\\\\\r\n]") <|> n("string-escaped-char") <|> n("escaped-single-quote")
	let string2char = try! "string-2-char" --> rt("[^\"\\\\\r\n]") <|> n("string-escaped-char") <|> n("escaped-double-quote")
	
	let stringEscapedChar = "string-escaped-char" --> n("unicode-scalar") <|> n("carriage-return") <|> n("line-feed") <|> n("tab-char") <|> n("backslash")
	let unicodeScalar = "unicode-scalar" --> t("\\") <+> t("u") <+> t("{") <+>  n("unicode-scalar-digits") <+> t("}")
	let unicodeScalarDigits = "unicode-scalar-digits" --> [n("digit")] <+> (n("digit") <|> [[]]) <+> (n("digit") <|> [[]]) <+> (n("digit") <|> [[]]) <+> (n("digit") <|> [[]]) <+> (n("digit") <|> [[]]) <+> (n("digit") <|> [[]]) <+> (n("digit") <|> [[]])
	let digit = try! "digit" --> rt("[0-9a-fA-F]")
	let carriageReturn = "carriage-return" --> t("\\") <+> t("r")
	let lineFeed = "line-feed" --> t("\\") <+> t("n")
	let tabChar = "tab-char" --> t("\\") <+> t("t")
	let backslash = "backslash" --> t("\\") <+> t("\\")
	let singleQuote = "escaped-single-quote" --> t("\\") <+> t("'")
	let doubleQuote = "escaped-double-quote" --> t("\\") <+> t("\"")
	
	var productions: [Production] = []
	productions.append(contentsOf: syntax)
	productions.append(rule)
	productions.append(contentsOf: optionalWhitespace)
	productions.append(contentsOf: whitespace)
	productions.append(contentsOf: comment)
	productions.append(contentsOf: commentContent)
	productions.append(contentsOf: commentContentChar)
	productions.append(contentsOf: commentAsterisk)
	productions.append(contentsOf: commentOpenParenthesis)
	productions.append(contentsOf: newlines)
	productions.append(assignmentOperator)
	productions.append(ruleNameContainer)
	productions.append(contentsOf: ruleName)
	productions.append(ruleNameChar)
	productions.append(contentsOf: expression)
	productions.append(alternation)
	productions.append(contentsOf: concatenation)
	productions.append(contentsOf: expressionElement)
	productions.append(expressionGroup)
	productions.append(expressionRepetition)
	productions.append(expressionOptional)
	productions.append(contentsOf: literal)
	productions.append(contentsOf: string1)
	productions.append(contentsOf: string2)
	productions.append(contentsOf: string1char)
	productions.append(contentsOf: string2char)
	productions.append(rangeLiteral)
	productions.append(contentsOf: singleCharLiteral)
	productions.append(contentsOf: stringEscapedChar)
	productions.append(unicodeScalar)
	productions.append(contentsOf: unicodeScalarDigits)
	productions.append(digit)
	productions.append(carriageReturn)
	productions.append(lineFeed)
	productions.append(tabChar)
	productions.append(backslash)
	productions.append(singleQuote)
	productions.append(doubleQuote)
	
	return Grammar(productions: productions, start: "syntax")
}

enum LiteralParsingError: Error {
	case invalidUnicodeScalar(Int)
	case invalidRange(lowerBound: Character, upperBound: Character, description: String)
}

public extension Grammar {
	
	/// Creates a new grammar from a specification in Backus-Naur Form (BNF)
	///
	/// 	<pattern1> ::= <alternative1> | <alternative2>
	///		<pattern2> ::= 'con' 'catenation'
	///
	/// - Parameters:
	///   - bnfString: String describing the grammar in BNF
	///   - start: Start non-terminal
	@available(*, unavailable, renamed: "init(bnf:start:)")
	init(bnfString: String, start: String) throws {
		try self.init(bnf: bnfString, start: start)
	}
	
	/// Creates a new grammar from a specification in Backus-Naur Form (BNF)
	///
	/// 	<pattern1> ::= <alternative1> | <alternative2>
	///		<pattern2> ::= 'con' 'catenation'
	///
	/// - Parameters:
	///   - bnf: String describing the grammar in BNF
	///   - start: Start non-terminal
	init(bnf bnfString: String, start: String) throws {
		let grammar = bnfGrammar
		let parser = EarleyParser(grammar: grammar)
		let syntaxTree = try parser
			.syntaxTree(for: bnfString)
			.explode{["expression"].contains($0)}
			.first!
			.filter{!["optional-whitespace", "newlines"].contains($0)}!
		
		let ruleDeclarations = syntaxTree.allNodes(where: {$0.name == "rule"})
		
		func ruleName(from container: SyntaxTree<NonTerminal, Range<String.Index>>) -> String {
			return container
				.allNodes(where: {$0.name == "rule-name-char"})
				.flatMap{$0.leafs}
				.reduce("") { partialResult, range -> String in
					partialResult.appending(bnfString[range])
			}
		}
		
		func character(fromCharacterExpression characterExpression: ParseTree) throws -> Character {
			guard let child = characterExpression.children?.first else {
				fatalError()
			}
			switch child {
			case .leaf(let range):
				return bnfString[range.lowerBound]
				
			case .node(key: "string-escaped-char", children: let children):
				guard let child = children.first else {
					fatalError()
				}
				switch child {
				case .leaf:
					fatalError()
					
				case .node(key: "unicode-scalar", children: let children):
					let hexString: String = children.dropFirst(3).dropLast().flatMap {$0.leafs}.map {bnfString[$0]}.joined()
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
				if children.count == 2 {
					let (lhsProductions, lhsAdd) = try makeProductions(from: children[0], named: "\(name)-c0")
					let (rhsProductions, rhsAdd) = try makeProductions(from: children[1], named: "\(name)-c1")
					
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
					
				default:
					fatalError()
				}
				
			default:
				fatalError()
			}
		}
		
		let (productions, helperRules): ([Production], [Production]) = try ruleDeclarations.reduce(into: ([], [])) { acc, ruleDeclaration in
			guard let children = ruleDeclaration.children, children.count == 3 else {
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
			self.init(productions: productions + helperRules + ["EOL" --> t("\n")], start: NonTerminal(name: start), utilityNonTerminals: helperRules.map {$0.pattern}.collect(Set.init))
		} else {
			self.init(productions: productions + helperRules, start: NonTerminal(name: start), utilityNonTerminals: helperRules.map {$0.pattern}.collect(Set.init))
		}
		
	}
}
