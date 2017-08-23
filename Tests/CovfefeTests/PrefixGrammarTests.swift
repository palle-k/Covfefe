//
//  PrefixGrammarTests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 23.08.17.
//

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
		let tokenizer = DefaultTokenizer(grammar: prefixGrammar)
		let parser = CYKParser(grammar: prefixGrammar)
		
		XCTAssertTrue(try parser.recognizes(tokenizer.tokenize("(a+b)-")))
		XCTAssertTrue(try parser.recognizes(tokenizer.tokenize("(a+b)/(c")))
		XCTAssertFalse((try? parser.recognizes(tokenizer.tokenize("(a+)"))) ?? false)
	}
}
