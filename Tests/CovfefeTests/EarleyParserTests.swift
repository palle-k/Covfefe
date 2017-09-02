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
	func testEarleyParser() throws {
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
		try print(parser.syntaxTree(for: tokenizer.tokenize(expression)))
	}
}
