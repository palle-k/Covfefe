//
//  EarleyParserTests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 02.09.17.
//

import XCTest
@testable import Covfefe
import Foundation

class EarleyParserTests: XCTestCase {
	func testEarleyParser1() throws {
		let grammarString = """
		<sum> ::= <sum> '+' <product> | <sum> '-' <product> | <product>
		<product> ::= <product> '*' <factor> | <product> '/' <factor> | <factor>
		<factor> ::= '(' <sum> ')' | <number>
		<number> ::= <digit> <number> | <digit>
		<digit> ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
		"""
		let grammar = try Grammar(bnfString: grammarString, start: "sum")
		let tokenizer = DefaultTokenizer(grammar: grammar)
		let parser = EarleyParser(grammar: grammar)
		let expression = "1+(2*3-4)"
		_ = try parser.syntaxTree(for: tokenizer.tokenize(expression)).mapLeafs{String(expression[$0])}
	}
	
	func testEarleyParser2() throws {
		let grammarString = """
		<expression>       ::= <binary-operation> | <brackets> | <unary-operation> | <number> | <variable>
		<brackets>         ::= '(' <expression> ')'
		<binary-operation> ::= <expression> <binary-operator> <expression>
		<binary-operator>  ::= '+' | '-' | '*' | '/'
		<unary-operation>  ::= <unary-operator> <expression>
		<unary-operator>   ::= '+' | '-'
		<number>           ::= <digit> | <digit> <number>
		<digit>            ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
		<variable>         ::= <letter> | <letter> <variable>
		<letter>           ::= "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J" | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T" | "U" | "V" | "W" | "X" | "Y" | "Z" | "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
		"""
		let grammar = try Grammar(bnfString: grammarString, start: "expression")
		let tokenizer = DefaultTokenizer(grammar: grammar)
		let parser = EarleyParser(grammar: grammar)
		let expression = "(a+b)*(-c)"
		_ = try parser.syntaxTree(for: tokenizer.tokenize(expression)).mapLeafs{String(expression[$0])}
	}
	
	func testEarleyEmpty() throws {
		let grammarString = """
		<start> ::= <item>
		<item> ::= <optional-whitespace> <name> <optional-whitespace> '=' <optional-whitespace> <value> <optional-whitespace>
		<name> ::= <letter> | <name> <letter>
		<letter> ::= "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
		<value> ::= <digit> | <value> <digit>
		<digit> ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
		<optional-whitespace> ::= <optional-whitespace> <whitespace> | ''
		<whitespace> ::= ' ' | '	'
		"""
		let grammar = try Grammar(bnfString: grammarString, start: "start")
		let parser = EarleyParser(grammar: grammar)
		let tokenizer = DefaultTokenizer(grammar: grammar)
		
		let expression = """
		hello=1337
		"""
		_ = try parser.syntaxTree(for: tokenizer.tokenize(expression)).mapLeafs{String(expression[$0])}
	}
	
	func testEarleyJSON() throws {
		let grammarString = """
		<any> ::= <optional-whitespace> <node> <optional-whitespace>
		<node> ::= <dictionary> | <array> | <value>
		<value> ::= <string> | <number> | <boolean> | <null>
		
		<dictionary> ::= "{" <dictionary-content> "}" | "{" <optional-whitespace> "}"
		<dictionary-content> ::= <dictionary-content> "," <optional-whitespace> <key-value-pair> <optional-whitespace> | <optional-whitespace> <key-value-pair> <optional-whitespace>
		<key-value-pair> ::= <string> <optional-whitespace> ":" <optional-whitespace> <any>

		<array> ::= "[" <array-contents> "]" | "[" <optional-whitespace> "]"
		<array-contents> ::= <array-contents> "," <optional-whitespace> <any> <optional-whitespace> | <optional-whitespace> <any> <optional-whitespace>

		<string> ::= '"' <string-content> '"'
		<string-content> ::= <string-content> <character> | <character>
		<letter> ::= "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J" | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T" | "U" | "V" | "W" | "X" | "Y" | "Z" | "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
		<digit> ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
		<whitespace> ::= ' ' | '	' | <EOL>
		<symbol> ::=  "|" | " " | "-" | "!" | "#" | "$" | "%" | "&" | "(" | ")" | "*" | "+" | "," | "-" | "." | "/" | ":" | ";" | ">" | "=" | "<" | "?" | "@" | "[" | "]" | "^" | "_" | "`" | "{" | "}" | "~" | "'"
		<character> ::= <letter> | <digit> | <whitespace> | <symbol>

		<number> ::= <integer> | <float>
		<integer> ::= <digit> | <integer> <digit>
		<float> ::= <integer> '.' <integer>

		<boolean> ::= 't' 'r' 'u' 'e' | 'f' 'a' 'l' 's' 'e'
		
		<null> ::= 'n' 'u' 'l' 'l'
		
		<optional-whitespace> ::= <optional-whitespace> <whitespace> | ''
		"""

		let grammar = try Grammar(bnfString: grammarString, start: "any")
		let parser = EarleyParser(grammar: grammar)
		let tokenizer = DefaultTokenizer(grammar: grammar)
		let expression = """
		{
			"firstName": "John",
			"lastName": "Smith",
			"isAlive": true,
			"age": 25,
			"address": {
				"streetAddress": "21 2nd Street",
				"city": "New York",
				"state": "NY",
				"postalCode": "10021-3100"
			},
			"phoneNumbers": [
				{
					"type": "home",
					"number": "212 555-1234"
				},
				{
					"type": "office",
					"number": "646 555-4567"
				},
				{
					"type": "mobile",
					"number": "123 456-7890"
				}
			],
			"children": [],
			"spouse": null
		}
		"""
		do {
			let tokenized = try tokenizer.tokenize(expression)
			_ = try parser.syntaxTree(for: tokenized)
		} catch let error as SyntaxError {
			print("Error: \(error.reason) at \(NSRange(error.range, in: expression)): \(expression[error.range])")
			XCTFail()
		}
	}
	
	func testEarleyBNF() throws {
		let grammar = bnfGrammar
		let parser = EarleyParser(grammar: grammar)
		let tokenizer = DefaultTokenizer(grammar: grammar)
		
		let expression = """
		<sum>     ::= <sum> '+' <product> | <sum> '-' <product>
		<sum>     ::= <product>
		<product> ::= <product> '*' <factor> | <product> '/' <factor>
		<product> ::= <factor>
		<factor>  ::= '(' <sum> ')'
		<factor>  ::= <number>
		<number>  ::= <number> <digit> | <digit>
		<digit>  ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
		"""
		do {
			let tokenized = try tokenizer.tokenize(expression)
			_ = try parser.syntaxTree(for: tokenized)
		} catch let error as SyntaxError {
			print("Error: \(error.reason) at \(NSRange(error.range, in: expression)): \(expression[error.range])")
			XCTFail()
		}
	}
	
	func testEarleyParserPerformance() throws {
		let grammarString = """
		<any> ::= <optional-whitespace> <node> <optional-whitespace>
		<node> ::= <dictionary> | <array> | <value>
		<value> ::= <string> | <number> | <boolean> | <null>

		<dictionary> ::= "{" <dictionary-content> "}" | "{" <optional-whitespace> "}"
		<dictionary-content> ::= <dictionary-content> "," <optional-whitespace> <key-value-pair> <optional-whitespace> | <optional-whitespace> <key-value-pair> <optional-whitespace>
		<key-value-pair> ::= <string> <optional-whitespace> ":" <optional-whitespace> <any>

		<array> ::= "[" <array-contents> "]" | "[" <optional-whitespace> "]"
		<array-contents> ::= <array-contents> "," <optional-whitespace> <any> <optional-whitespace> | <optional-whitespace> <any> <optional-whitespace>

		<string> ::= '"' <string-content> '"'
		<string-content> ::= <string-content> <character> | <character>
		<letter> ::= "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J" | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T" | "U" | "V" | "W" | "X" | "Y" | "Z" | "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
		<digit> ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
		<whitespace> ::= ' ' | '	' | <EOL>
		<symbol> ::=  "|" | " " | "-" | "!" | "#" | "$" | "%" | "&" | "(" | ")" | "*" | "+" | "," | "-" | "." | "/" | ":" | ";" | ">" | "=" | "<" | "?" | "@" | "[" | "]" | "^" | "_" | "`" | "{" | "}" | "~" | "'"
		<character> ::= <letter> | <digit> | <whitespace> | <symbol>

		<number> ::= <integer> | <float>
		<integer> ::= <digit> | <integer> <digit>
		<float> ::= <integer> '.' <integer>

		<boolean> ::= 't' 'r' 'u' 'e' | 'f' 'a' 'l' 's' 'e'

		<null> ::= 'n' 'u' 'l' 'l'

		<optional-whitespace> ::= <optional-whitespace> <whitespace> | ''
		"""

		let grammar = try Grammar(bnfString: grammarString, start: "any")
		let parser = EarleyParser(grammar: grammar)
		let tokenizer = DefaultTokenizer(grammar: grammar)
		let expression = """
		{
			"firstName": "John",
			"lastName": "Smith",
			"isAlive": true,
			"age": 25,
			"address": {
				"streetAddress": "21 2nd Street",
				"city": "New York",
				"state": "NY",
				"postalCode": "10021-3100"
			},
			"phoneNumbers": [
				{
					"type": "home",
					"number": "212 555-1234"
				},
				{
					"type": "office",
					"number": "646 555-4567"
				},
				{
					"type": "mobile",
					"number": "123 456-7890"
				}
			],
			"children": [],
			"spouse": null
		}
		"""
		let tokenized = try tokenizer.tokenize(expression)

		self.measure {
			do {
				_ = try parser.syntaxTree(for: tokenized)
			} catch let error as SyntaxError {
				print("Error: \(error.reason) at \(NSRange(error.range, in: expression)): \(expression[error.range])")
				XCTFail()
			} catch {
				XCTFail()
			}
		}
	}
}
