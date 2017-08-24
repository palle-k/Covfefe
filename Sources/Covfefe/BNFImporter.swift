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
	/*
	<syntax>         ::= <rule> | <rule> <syntax>
	<rule>           ::= <opt-whitespace> "<" <rule-name> ">" <opt-whitespace> "::=" <opt-whitespace> <expression> <line-end>
	<opt-whitespace> ::= " " <opt-whitespace> | ""
	<expression>     ::= <list> | <list> <opt-whitespace> "|" <opt-whitespace> <expression>
	<line-end>       ::= <opt-whitespace> <EOL> | <line-end> <line-end>
	<list>           ::= <term> | <term> <opt-whitespace> <list>
	<term>           ::= <literal> | "<" <rule-name> ">"
	<literal>        ::= '"' <text1> '"' | "'" <text2> "'"
	<text1>          ::= "" | <character1> <text1>
	<text2>          ::= "" | <character2> <text2>
	<character>      ::= <letter> | <digit> | <symbol>
	<letter>         ::= "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J" | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T" | "U" | "V" | "W" | "X" | "Y" | "Z" | "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
	<digit>          ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
	<symbol>         ::=  "|" | " " | "-" | "!" | "#" | "$" | "%" | "&" | "(" | ")" | "*" | "+" | "," | "-" | "." | "/" | ":" | ";" | ">" | "=" | "<" | "?" | "@" | "[" | "\" | "]" | "^" | "_" | "`" | "{" | "}" | "~"
	<character1>     ::= <character> | "'"
	<character2>     ::= <character> | '"'
	<rule-name>      ::= <letter> | <rule-name> <rule-char>
	<rule-char>      ::= <letter> | <digit> | "-"
	*/
	/*
	let symbols = ["|", " ", "-", "!", "#", "$", "%", "&", "(", ")", "*", "+", ",", ".", "/", ":", ";", ">", "=", "<", "?", "@", "[", "\\", "]", "^", "_", "`", "{", "}", "~"].map(t).map{ProductionString([$0])}.collect(ProductionResult.init(symbols:))
	
	let syntax 		= "syntax" 				--> n("rule") <+> n("line-end") <|> n("rule") <|> n("rule") <+> n("syntax")
	let rule 		= "rule"				--> n("optional-whitespace") <+> t("<") <+> n("rule-name") <+> t(">") <+> n("optional-whitespace") <+> n("assign") <+> n("optional-whitespace") <+> n("expression")
	let assign 		= "assign" 				--> t(":") <+> t(":") <+> t("=")
	let optWs 		= "optional-whitepace" 	--> t(" ") <|> t("\t") <|> t(" ") <+> n("optional-whitepace") <|> t("\t") <+> n("optional-whitepace") <|> [[]]
	let expression 	= "expression"			--> n("list") <|> n("list") <+> n("optional-whitespace") <+> t("|") <+> n("optional-whitespace") <+> n("expression")
	let lineEnd 	= "line-end" 			--> n("optional-whitespace") <+> t("\n") <|> n("line-end") <+> n("line-end")
	let list 		= "list" 				--> n("term") <|> n("term") <+> n("optional-whitespace") <+> n("list")
	let term 		= "term" 				--> n("literal") <|> t("<") <+> n("rule-name") <+> t(">")
	let literal 	= "literal" 			--> t("\"") <+> n("text-1") <+> t("\"") <|> t("'") <+> n("text-2") <+> t("'")
	let text1		= "text-1" 				--> [[]] <|> n("char-1") <+> n("text-1")
	let text2 		= "text-2" 				--> [[]] <|> n("char-2") <+> n("text-2")
	let character 	= "char" 				--> SymbolSet.letters <|> SymbolSet.numbers <|> symbols
	let character1 	= "char-1" 				--> n("char") <|> t("'")
	let character2 	= "char-2" 				--> n("char") <|> t("\"")
	let ruleName 	= "rule-name" 			--> SymbolSet.letters <|> n("rule-name") <+> n("rule-char")
	let ruleChar 	= "rule-char" 			--> SymbolSet.letters <|> SymbolSet.numbers <|> t("-")
	
	var productions: [Production] = []
	productions += syntax
	productions += [rule, assign]
	productions += optWs
	productions += expression
	productions += lineEnd
	productions += list
	productions += term
	productions += literal
	productions += text1
	productions += text2
	productions += character
	productions += character1
	productions += character2
	productions += ruleName
	productions += ruleChar
	*/
	
	let symbols = [
		"|", " ", "-", "!", "#", "$", "%",
		"&", "(", ")", "*", "+", ",", ".",
		"/", ":", ";", ">", "=", "<", "?",
		"@", "[", "\\", "]", "^", "_", "`",
		"{", "}", "~", " ", "\t"
	].map(t).map{ProductionString([$0])}.collect(ProductionResult.init(symbols:))
	
	let syntax = "syntax" --> n("rule") <|> n("rule") <+> n("newlines") <|> n("rule") <+> n("newlines") <+> n("syntax")
	let rule = "rule" --> n("optional-whitespace") <+> n("rule-name-container") <+> n("optional-whitespace") <+> n("assignment-operator") <+> n("optional-whitespace") <+> n("expression") <+> n("optional-whitespace")
	
	let optionalWhitespace = "optional-whitespace" --> [[]] <|> SymbolSet.whitespace <|> SymbolSet.whitespace <+> [n("optional-whitespace")]
	let newlines = "newlines" --> t("\n") <|> t("\n") <+> n("optional-whitespace") <+> n("newlines")
	
	let assignmentOperator = "assignment-operator" --> t(":") <+> t(":") <+> t("=")
	
	let ruleNameContainer = "rule-name-container" --> t("<") <+> n("rule-name") <+> t(">")
	let ruleNameChar = "rule-name-char" --> SymbolSet.alphanumerics <|> t("-") <|> t(" ")
	let ruleName = "rule-name" --> n("rule-name-char") <|> n("rule-name-char") <+> n("rule-name")
	
	let expression = "expression" --> n("concatenation") <|> n("alternation")
	let alternation = "alternation" --> n("concatenation") <+> n("optional-whitespace") <+> t("|") <+> n("optional-whitespace") <+> n("expression")
	let concatenation = "concatenation" --> n("expression-element") <|> n("expression-element") <+> n("optional-whitespace") <+> n("concatenation")
	let expressionElement = "expression-element" --> n("literal") <|> n("rule-name-container")
	let literal = "literal" --> t("'") <+> n("string-1") <+> t("'") <|> t("\"") <+> n("string-2") <+> t("\"")
	let string1 = "string-1" --> n("string-char-1") <|> n("string-char-1") <+> [n("string-1")] <|> [[]]
	let string2 = "string-2" --> n("string-char-2") <|> n("string-char-2") <+> [n("string-2")] <|> [[]]
	let stringChar = "string-char" --> SymbolSet.alphanumerics <|> symbols
	let stringChar1 = "string-char-1" --> n("string-char") <|> t("\"")
	let stringChar2 = "string-char-2" --> n("string-char") <|> t("'")
	
	
	var productions: [Production] = []
	productions.append(contentsOf: syntax)
	productions.append(rule)
	productions.append(contentsOf: optionalWhitespace)
	productions.append(contentsOf: newlines)
	productions.append(assignmentOperator)
	productions.append(ruleNameContainer)
	productions.append(contentsOf: ruleNameChar)
	productions.append(contentsOf: ruleName)
	productions.append(contentsOf: expression)
	productions.append(alternation)
	productions.append(contentsOf: concatenation)
	productions.append(contentsOf: expressionElement)
	productions.append(contentsOf: literal)
	productions.append(contentsOf: string1)
	productions.append(contentsOf: string2)
	productions.append(contentsOf: stringChar)
	productions.append(contentsOf: stringChar1)
	productions.append(contentsOf: stringChar2)
	
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
			.explode{["rule-name", "string", "expression"].contains($0)}
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
		
		func string(from literal: SyntaxTree<NonTerminal, Range<String.Index>>) -> String {
			return literal
				.allNodes(where: {$0.name == "string-char-1" || $0.name == "string-char-2"})
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
