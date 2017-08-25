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
var bnfGrammar: Grammar {
	
	let syntax = "syntax" --> n("rule") <|> n("rule") <+> n("newlines") <|> n("rule") <+> n("newlines") <+> n("syntax")
	let rule = "rule" --> n("optional-whitespace") <+> n("rule-name-container") <+> n("optional-whitespace") <+> n("assignment-operator") <+> n("optional-whitespace") <+> n("expression") <+> n("optional-whitespace")
	
	let optionalWhitespace = "optional-whitespace" --> [[]] <|> SymbolSet.whitespace <|> SymbolSet.whitespace <+> [n("optional-whitespace")]
	let newlines = "newlines" --> t("\n") <|> t("\n") <+> n("optional-whitespace") <+> n("newlines")
	
	let assignmentOperator = "assignment-operator" --> t(":") <+> t(":") <+> t("=")
	
	let ruleNameContainer = "rule-name-container" --> t("<") <+> n("rule-name") <+> t(">")
	let ruleName = try! "rule-name" --> rt("[a-zA-Z0-9-_]+")
	
	let expression = "expression" --> n("concatenation") <|> n("alternation")
	let alternation = "alternation" --> n("concatenation") <+> n("optional-whitespace") <+> t("|") <+> n("optional-whitespace") <+> n("expression")
	let concatenation = "concatenation" --> n("expression-element") <|> n("expression-element") <+> n("optional-whitespace") <+> n("concatenation")
	let expressionElement = "expression-element" --> n("literal") <|> n("rule-name-container")
	let literal = "literal" --> t("'") <+> n("string-1") <+> t("'") <|> t("\"") <+> n("string-2") <+> t("\"")
	let string1 = try! "string-1" --> rt("[^']+(?=')") <|> [[]]
	let string2 = try! "string-2" --> rt("[^\"]+(?=\")") <|> [[]]
	
	var productions: [Production] = []
	productions.append(contentsOf: syntax)
	productions.append(rule)
	productions.append(contentsOf: optionalWhitespace)
	productions.append(contentsOf: newlines)
	productions.append(assignmentOperator)
	productions.append(ruleNameContainer)
	productions.append(ruleName)
	productions.append(contentsOf: expression)
	productions.append(alternation)
	productions.append(contentsOf: concatenation)
	productions.append(contentsOf: expressionElement)
	productions.append(contentsOf: literal)
	productions.append(contentsOf: string1)
	productions.append(contentsOf: string2)
	
	return Grammar(productions: productions, start: "syntax")
}

public extension Grammar {
	
	/// Creates a new grammar from a specification in Backus-Naur Form (BNF)
	///
	///     <pattern1> ::= <alternative1> | <alternative2>
	///		<pattern2> ::= 'con' 'catenation'
	///
	/// - Parameters:
	///   - bnfString: String describing the grammar in BNF
	///   - start: Start non-terminal
	public init(bnfString: String, start: String) throws {
		let grammar = bnfGrammar
		let tokenizer = DefaultTokenizer(grammar: grammar)
		let parser = CYKParser(grammar: grammar)
		let syntaxTree = try parser
			.syntaxTree(for: tokenizer.tokenize(bnfString))
			.explode{["expression"].contains($0)}
			.first!
			.filter{!["optional-whitespace", "newlines"].contains($0)}!
		
		let ruleDeclarations = syntaxTree.allNodes(where: {$0.name == "rule"})
		
		func ruleName(from container: SyntaxTree<NonTerminal, Range<String.Index>>) -> String {
			return container
				.allNodes(where: {$0.name == "rule-name"})
				.flatMap{$0.leafs}
//				.leafs
				.reduce("") { partialResult, range -> String in
					partialResult.appending(bnfString[range])
			}
		}
		
		func string(from literal: SyntaxTree<NonTerminal, Range<String.Index>>) -> String {
			return literal
				.allNodes(where: {$0.name == "string-1" || $0.name == "string-2"})
				.flatMap{$0.leafs}
				.reduce("") { partialResult, range -> String in
					partialResult.appending(bnfString[range])
			}
		}
		
		func makeProductions(from expression: SyntaxTree<NonTerminal, Range<String.Index>>, named name: String) -> [Production] {
			guard let type = expression.root?.name else {
				return []
			}
			guard let children = expression.children else {
				return []
			}
			switch type {
			case "alternation":
				return makeProductions(from: children[0], named: name) + makeProductions(from: children[2], named: name)
				
			case "concatenation":
				if children.count == 2 {
					let lhsProduction = makeProductions(from: children[0], named: name)
					let rhsProduction = makeProductions(from: children[1], named: name)
					assert(lhsProduction.count == 1)
					assert(rhsProduction.count == 1)
					return [Production(pattern: NonTerminal(name: name), production: lhsProduction[0].production + rhsProduction[0].production)]
				} else if children.count == 1 {
					return makeProductions(from: children[0], named: name)
				} else {
					fatalError()
				}
				
			case "expression-element":
				guard children.count == 1 else {
					return []
				}
				switch children[0].root!.name {
				case "literal":
					let terminalValue = string(from: children[0])
					if terminalValue.isEmpty {
						return [Production(pattern: NonTerminal(name: name), production: [])]
					} else {
						return [Production(pattern: NonTerminal(name: name), production: [t(terminalValue)])]
					}
					
				case "rule-name-container":
					let nonTerminalName = ruleName(from: children[0])
					return [Production(pattern: NonTerminal(name: name), production: [n(nonTerminalName)])]
					
				default:
					fatalError()
				}
				
			default:
				fatalError()
			}
		}
		
		let productions = ruleDeclarations.flatMap { ruleDeclaration -> [Production] in
			guard let children = ruleDeclaration.children, children.count == 3 else {
				return []
			}
			let name = ruleName(from: children[0])
			return makeProductions(from: children[2], named: name)
		}
		
		self.init(productions: productions, start: NonTerminal(name: start))
	}
}
