//
//  PerformanceTests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 17.02.18.
//

import XCTest
@testable import Covfefe

class PerformanceTests: XCTestCase {
	static let jsonGrammar: Grammar = {
		let grammarString = """
		<any> ::= <optional-whitespace> <node> <optional-whitespace>
		<node> ::= <dictionary> | <array> | <value>
		<value> ::= <string> | <number> | <boolean> | <null>
		
		<dictionary> ::= "{" <dictionary-content> "}" | "{" <optional-whitespace> "}"
		<dictionary-content> ::= <dictionary-content> "," <optional-whitespace> <key-value-pair> <optional-whitespace> | <optional-whitespace> <key-value-pair> <optional-whitespace>
		<key-value-pair> ::= <key> <optional-whitespace> ":" <optional-whitespace> <any>

		<array> ::= "[" <array-contents> "]" | "[" <optional-whitespace> "]"
		<array-contents> ::= <array-contents> "," <optional-whitespace> <any> <optional-whitespace> | <optional-whitespace> <any> <optional-whitespace>

		<key> ::= '"' [{<character>}] '"'
		<string> ::= '"' [{<character>}] '"'
		<string-content> ::= <string-content> <character> | <character>
		<digit-except-zero> ::= '1' ... '9'
		<digit> ::= '0' ... '9'
		<hex-digit> ::= <digit> | 'a' ... 'f' | 'A' ... 'F'
		<whitespace> ::= ' ' | '\\t' | <EOL>
		<character> ::= <escaped-sequence> | '#' ... '[' (* includes all letters and numbers *) | ']' ... '~' | '!' | <whitespace>

		<escaped-sequence> ::= '\\\\' <escaped>
		<escaped> ::= '"' | '\\\\' | '/' | 'b' | 'f' | 'n' | 'r' | 't' | 'u' <hex-digit> <hex-digit> <hex-digit> <hex-digit>

		<number> ::= ['-'] <integer> ['.' {'0' ... '9'}] [('E' | 'e') <exponent>]
		<integer> ::= '1'...'9' [{'0'...'9'}]
		<integer-prefix> ::= <digit-except-zero> | <integer-prefix> <digit>
		<fraction> ::= <digit> | <fraction> <digit>
		<exponent> ::= ['-' | '+'] <integer>

		<boolean> ::= 't' 'r' 'u' 'e' | 'f' 'a' 'l' 's' 'e'
		
		<null> ::= 'n' 'u' 'l' 'l'
		
		<optional-whitespace> ::= <optional-whitespace> <whitespace> | ''
		"""
		return try! Grammar(bnf: grammarString, start: "any")
	}()
	
	func testEarleyPerformance() {
		let grammar = PerformanceTests.jsonGrammar
		let parser = EarleyParser(grammar: grammar)
		
		let testString = """
		{"widget": {
			"debug": "on",
			"window": {
				"title": "Sample Konfabulator Widget",
				"name": "main_window",
				"width": 500,
				"height": 500
			},
			"image": {
				"src": "Images/Sun.png",
				"name": "sun1",
				"hOffset": 250,
				"vOffset": 250,
				"alignment": "center"
			},
			"text": {
				"data": "Click Here",
				"size": 36,
				"style": "bold",
				"name": "text1",
				"hOffset": 250,
				"vOffset": 100,
				"alignment": "center",
				"onMouseUp": "sun1.opacity = (sun1.opacity / 100) * 90;"
			}
		}}
		"""
		
		measure {
			for _ in 0 ..< 3 {
				if parser.recognizes(testString) == false {
					XCTFail()
				}
			}
		}
	}
}
