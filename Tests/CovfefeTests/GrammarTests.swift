//
//  GrammarTests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 07.08.17.
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

import XCTest
@testable import Covfefe

class GrammarTests: XCTestCase {
	
    func testLinearGrammar() {
		let productions = "S" --> (t("(") <+> n("S") <+> t(")")) <|> (t("[") <+> n("S") <+> t("]")) <|> (t("{") <+> n("S") <+> t("}")) <|> [[]]
		guard let grammar = try? LinearGrammar(productions: productions, start: "S") else {
			XCTFail()
			return
		}
		
		for string in ["", "()", "[]", "{}", "(())", "[[]]", "{{}}"] {
			XCTAssertTrue(grammar.contains(word: string))
			if !grammar.contains(word: string) {
				print("Expected \(string) to be in grammar.")
			}
		}
		
		for string in ["(()"] {
			XCTAssertFalse(grammar.contains(word: string))
		}
    }
	
	func testCYKEmpty() {
		let S = "S" --> [[]]
		let grammar = Grammar(productions: S, start: "S")
		let parser = CYKParser(grammar: grammar)
		XCTAssertTrue(parser.recognizes(""))
	}
	
	func testCYK() {
		let S = "S" --> (n("A") <+> n("B")) <|> (n("C") <+> n("D")) <|> (n("A") <+> n("T")) <|> (n("C") <+> n("U")) <|> (n("S") <+> n("S"))
		let T = "T" --> n("S") <+> n("B")
		let U = "U" --> n("S") <+> n("D")
		
		let A = "A" --> [t("(")]
		let B = "B" --> [t(")")]
		let C = "C" --> [t("{")]
		let D = "D" --> [t("}")]
		
		let grammar = Grammar(productions: S + [T, U, A, B, C, D], start: "S")
		let parser = CYKParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("(){()}"))
		XCTAssertFalse(parser.recognizes("(){"))
		XCTAssertFalse(parser.recognizes("){}"))
		
		do {
			try print(CYKParser(grammar: grammar).syntaxTree(for: "(){()}").debugDescription)
		} catch {
			XCTFail()
		}
	}
	
	func testCYK2() {
		let S = "S" --> (n("T") <+> n("S")) <|> (n("C") <+> n("T")) <|> t("a")
		let T = "T" --> (n("A") <+> n("U")) <|> (n("T") <+> n("T")) <|> t("c")
		let U = "U" --> (n("S") <+> n("B")) <|> (n("A") <+> n("B"))
		let A = "A" --> t("a")
		let B = "B" --> t("b")
		let C = "C" --> t("c")
		
		let grammar = Grammar(productions: S + T + U + [A, B, C], start: "S")
		let parser = CYKParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("ccaab"))
		XCTAssertTrue(parser.recognizes("aabcc"))
	}
	
	func testCYK3() {
		let S = "S" --> (n("X") <+> n("U")) <|> (n("S") <+> n("V")) <|> (n("Neg") <+> n("S")) <|> SymbolSet.letters <|> (n("VarStart") <+> n("Var"))
		let X = "X" --> t("(")
		let Y = "Y" --> t(")")
		let V = "V" --> n("Op") <+> n("S")
		let U = "U" --> n("S") <+> n("Y")
		let Op = "Op" --> t("+") <|> t("-") <|> t("*") <|> t("/")
		let Neg = "Neg" --> t("-")
		let VarStart = "VarStart" --> SymbolSet.letters <|> (n("VarStart") <+> n("Var"))
		let Var = "Var" --> SymbolSet.alphanumerics <|> (n("Var") <+> n("Var"))
		
		let grammar = Grammar(productions: S + Op + VarStart + Var + [X, Y, U, V, Neg], start: "S")
		let parser = CYKParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("(-a+b)*-(b+a)/(((b-a)+(a-b)*(a-b))/-(b-a))"))
		XCTAssertFalse(parser.recognizes("a+b)*(b+a)/(((b-a)+(a-b)*(a-b))/(b-a))"))
		XCTAssertFalse(parser.recognizes("()*(b+a)/(((b-a)+(a-b)*(a-b))/(b-a))"))
		XCTAssertFalse(parser.recognizes("(a+b)(b+a)/(((b-a)+(a-b)*(a-b))/(b-a))"))
		XCTAssertFalse(parser.recognizes("(a+b)*(b+a)/(((b-a)+(a-b)*(a-b))/(b-a)"))
	}
	
	func testProgrammingLanguage() throws {
		let anyIdentifier = try rt("\\b[a-zA-Z_][a-zA-Z0-9_]*\\b")
		let whitespace = try rt("\\s+")
		let constant = try rt("\\blet\\b")
		let variable = try rt("\\bvar\\b")
		let numberLiteral = try rt("\\b[0-9]+(\\.[0-9]+)?\\b")
		let stringLiteral = try rt("\"[^\\\"]*\"")
		
		let whitespaceProduction = "Whitespace" --> whitespace
		let assignmentOperator = "Assignment" --> t("=")
		let binaryOperator = "BinaryOperator" --> t("+") <|> t("-") <|> t("*") <|> t("/")
		let prefixOperator = "PrefixOperator" --> t("+") <|> t("-")
		let colon = "Colon" --> t(":")
		
		let varDeclaration = "VarDeclaration" -->
			n("VarDeclarationKeyword") <+> n("VarDeclarationRest")
		
		let varKeyword = "VarDeclarationKeyword" -->
			constant
			<|> variable
		
		let varDeclarationRest = "VarDeclarationRest" -->
			n("Whitespace") <+> n("VarNameType")
			<|> n("Whitespace") <+> n("VarName")
			<|> n("Whitespace") <+> n("VarNameAssignment")
		
		let varNameType = "VarNameType" -->
			n("VarName") <+> n("VarNameTypeRest")
			<|> n("VarName") <+> n("VarTypeBegin")
		
		let varNameTypeRest = "VarNameTypeRest" --> 
			n("Whitespace") <+> n("VarTypeBegin")
		
		let varTypeBegin = "VarTypeBegin" -->
			n("Colon") <+> n("VarType")
		
		let varType = "VarType" -->
			n("Whitespace") <+> n("VarType")
			<|> anyIdentifier
		
		let varName = "VarName" --> anyIdentifier
		
		let varDeclarationProductions = [varDeclaration, varName, varNameTypeRest, varTypeBegin] + varType + varNameType + varKeyword + varDeclarationRest
		
		let varNameAssignment = "VarNameAssignment" -->
			n("VarNameType") <+> n("VarNameAssignmentRest")
			<|> n("VarName") <+> n("VarNameAssignmentRest")
			<|> n("VarNameType") <+> n("VarAssignment")
			<|> n("VarName") <+> n("VarAssignment")
		
		let varNameAssignmentRest = "VarNameAssignmentRest" -->
			n("Whitespace") <+> n("VarAssignment")
		
		let varAssignment = "VarAssignment" -->
			n("Assignment") <+> n("ValueExpression")
		
		let varAssignmentProductions = varNameAssignment + [varAssignment, varNameAssignmentRest]
		
		let valueExpression = "ValueExpression" -->
			n("ParenthesisExpressionBegin") <+> n("CloseParenthesis")
			<|> n("Whitespace") <+> n("ValueExpression")
			<|> n("ValueExpression") <+> n("Whitespace")
			<|> n("PrefixOperator") <+> n("ValueExpression")
			<|> n("BinaryOperationStart") <+> n("ValueExpression")
			<|> numberLiteral
			<|> anyIdentifier
			<|> stringLiteral
		
		let binaryOperationStart = "BinaryOperationStart" --> n("ValueExpression") <+> n("BinaryOperator")
		
		let valueExpressionBegin = "ParenthesisExpressionBegin" -->
			n("OpenParenthesis") <+> n("ValueExpression")
		
		let openParenthesis = "OpenParenthesis" -->
			t("(")
			<|> n("OpenParenthesis") <+> n("Whitespace")
		
		let closeParenthesis = "CloseParenthesis" -->
			t(")")
			<|> n("Whitespace") <+> n("CloseParenthesis")
		
		
		let functionCall = "FunctionCall" --> n("FunctionName") <+> n("FunctionArguments")
		let functionName = "FunctionName" -->
			n("Whitespace") <+> n("FunctionName")
			<|> n("FunctionName") <+> n("Whitespace")
			<|> anyIdentifier
		
		let functionArguments = "FunctionArguments" --> n("FunctionArgumentsStart") <+> n("CloseParenthesis")
		let functionArgumentsStart = "FunctionArgumentsStart" -->
			n("OpenParenthesis") <+> n("FunctionArgumentList")
			<|> n("OpenParenthesis") <+> n("ValueExpression")
		
		let functionArgumentList = "FunctionArgumentList" -->
			n("FunctionArgument") <+> n("FunctionArgumentSeparator")
		
		
		let varAssignmentExpressionProductions = valueExpression + [valueExpressionBegin] + openParenthesis + closeParenthesis
		
		let grammar = Grammar(productions: [whitespaceProduction, assignmentOperator, binaryOperationStart, colon] + binaryOperator + prefixOperator + varDeclarationProductions + varAssignmentProductions + varAssignmentExpressionProductions, start: "VarDeclaration")
		let parser = CYKParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("let hello"))
		XCTAssertTrue(parser.recognizes("var hello"))
		XCTAssertTrue(parser.recognizes("let _hello123"))
		XCTAssertTrue(parser.recognizes("let hello=42"))
		XCTAssertTrue(parser.recognizes("let hello= 42"))
		XCTAssertTrue(parser.recognizes("let hello = 42"))
		XCTAssertTrue(parser.recognizes("let hello = 42.1337"))
		
		XCTAssertFalse(parser.recognizes("let 1hello"))
		XCTAssertFalse(parser.recognizes("bar hello"))
		XCTAssertFalse(parser.recognizes("var hello = "))
		XCTAssertFalse(parser.recognizes("var hello 42"))
		XCTAssertFalse(parser.recognizes("varhello = 42"))
		XCTAssertFalse(parser.recognizes("var hello = 42."))
		XCTAssertFalse(parser.recognizes("var hello = .1337"))
		
		let tree = try parser.syntaxTree(for: "let hello = \"World\"")
		let optimizedTree = tree
			.filter{!["Whitespace", "OpenParenthesis", "CloseParenthesis", "Assignment", "Colon"].contains($0)}!
			.compressed()
			.explode{["BinaryOperationStart", "ParenthesisExpressionBegin", "VarNameAssignment", "VarNameAssignmentRest", "VarNameType", "VarTypeBegin"].contains($0)}
			.first!
			.compressed()
	}
	
	func testNonNormalizedGrammar() {
		let expression = try! "Expr" -->
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
	}

    static var allTests = [
        ("testLinearGrammar", testLinearGrammar),
        ("testCYK1", testCYK),
        ("testCYK2", testCYK2),
        ("testCYK3", testCYK3),
    ]
}
