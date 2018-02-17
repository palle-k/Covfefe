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

		<key> ::= '"' <string-content> '"' | '"' '"'
		<string> ::= '"' <string-content> '"' | '"' '"'
		<string-content> ::= <string-content> <character> | <character>
		<letter> ::= "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J" | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T" | "U" | "V" | "W" | "X" | "Y" | "Z" | "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
		<digit-except-zero> ::= '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
		<digit> ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
		<hex-digit> ::= <digit> | 'a' | 'A' | 'b' | 'B' | 'c' | 'C' | 'd' | 'D' | 'e' | 'E' | 'f' | 'F'
		<whitespace> ::= ' ' | '	' | <EOL>
		<symbol> ::=  "|" | " " | "	" | "-" | "!" | "#" | "$" | "%" | "&" | "(" | ")" | "*" | "+" | "," | "-" | "." | "/" | ":" | ";" | ">" | "=" | "<" | "?" | "@" | "[" | "]" | "^" | "_" | "`" | "{" | "}" | "~" | "'"
		<character> ::= <letter> | <digit> | <symbol> | <escaped-sequence>

		<escaped-sequence> ::= '\\' <escaped>
		<escaped> ::= '"' | '\\' | '/' | 'b' | 'f' | 'n' | 'r' | 't' | 'u' <hex-digit> <hex-digit> <hex-digit> <hex-digit>

		<number> ::= <optional-minus-sign> <integer> <optional-float> <optional-exponent>
		<optional-minus-sign> ::= '-' | ''
		<integer> ::= <digit> | <integer-prefix> <digit>
		<integer-prefix> ::= <digit-except-zero> | <integer-prefix> <digit>
		<optional-float> ::= '' | '.' <fraction>
		<fraction> ::= <digit> | <fraction> <digit>
		<optional-exponent> ::= '' | 'E' <exponent> | 'e' <exponent>
		<exponent> ::= <sign> <integer>
		<sign> ::= '+' | '-' | ''

		<boolean> ::= 't' 'r' 'u' 'e' | 'f' 'a' 'l' 's' 'e'
		
		<null> ::= 'n' 'u' 'l' 'l'
		
		<optional-whitespace> ::= <optional-whitespace> <whitespace> | ''
		"""
		return try! Grammar(bnfString: grammarString, start: "any")
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
				_ = parser.recognizes(testString)
			}
		}
	}
}
