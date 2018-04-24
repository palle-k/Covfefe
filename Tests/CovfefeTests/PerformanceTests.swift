//
//  PerformanceTests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 17.02.18.
//  Copyright (c) 2018 Palle Klewitz
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

extension PerformanceTests {
	static let allTests = [
		("testEarleyPerformance", testEarleyPerformance),
	]
}
