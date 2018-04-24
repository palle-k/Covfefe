//
//  PrefixGrammarTests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 23.08.17.
//  Copyright (c) 2017 - 2018 Palle Klewitz
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

class PrefixGrammarTests: XCTestCase {
	func testPrefixGrammar() throws {
		let expression = "Expr" -->
			n("BinOperation")
			<|> n("Brackets")
			<|> n("UnOperation")
			<|> n("Num")
			<|> n("Var")
			<|> n("Whitespace") <+> n("Expr")
			<|> n("Expr") <+> n("Whitespace")
		
		let BracketExpr = "Brackets" --> t("(") <+> n("Expr") <+> t(")")
		let BinOperation = "BinOperation" --> n("Expr") <+> n("Op") <+> n("Expr")
		let BinOp = "Op" --> t("+") <|> t("-") <|> t("*") <|> t("/")
		
		let UnOperation = "UnOperation" --> n("UnOp") <+> n("Expr")
		let UnOp = "UnOp" --> t("+") <|> t("-")
		let Num = try! "Num" --> rt("\\b\\d+(\\.\\d+)?\\b")
		let Var = try! "Var" --> rt("\\b[a-zA-Z_][a-zA-Z0-9_]*\\b")
		let Whitespace = try! "Whitespace" --> rt("\\s+")
		
		let grammar = Grammar(productions: expression + BinOp + UnOp + [Num, Var, BracketExpr, BinOperation, UnOperation, Whitespace], start: "Expr")
		let prefixGrammar = grammar.prefixGrammar()
		let parser = CYKParser(grammar: prefixGrammar)
		
		XCTAssertTrue(parser.recognizes("(a+b)-"))
		XCTAssertTrue(parser.recognizes("(a+b)/(c"))
		XCTAssertFalse(parser.recognizes("(a+)"))
	}
}


extension PrefixGrammarTests {
	static let allTests = [
		("testPrefixGrammar", testPrefixGrammar),
	]
}
