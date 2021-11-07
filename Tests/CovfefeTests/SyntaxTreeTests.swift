//
//  SyntaxTreeTests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 13.08.17.
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
import XCTest
@testable import Covfefe

class SyntaxTreeTests: XCTestCase {
	private var dotGrammar: Grammar {
		var productions: [Production] = []
		
		let whitespace = try! "W" --> re("\\s+")
		let anyIdentifier = try! "Identifier" --> re("\\b[a-zA-Z_][a-zA-Z0-9_]+\\b")
		let anyString = try! "String" --> re("\"[^\"]*\"")
		let value = "Value" --> n("Identifier") <|> n("String") <|> n("W") <+> n("Value") <|> n("Value") <+> n("W")
		productions += whitespace + anyIdentifier + anyString + value
		
		let graphType = try! "Type" --> re("\\bdigraph\\b") <|> re("\\bgraph\\b")
		let digraph = "Graph" --> n("Type") <+> n("W") <+> n("GraphContentWrap") <|> n("Type") <+> n("GraphContentWrap")
		let contentWrapper = "GraphContentWrap" --> t("{") <+> n("C") <+> t("}")
		let content = "C" --> n("C") <+> n("C") <|> n("Node") <|> n("Edge") <|> n("Subgraph") <|> n("Attribute")
		productions += digraph + contentWrapper + content + graphType
		
		let node = "Node" --> n("Value") <+> n("W") <+> n("AttributeWrapper") <|> n("Value") <+> n("AttributeWrapper") <|> n("Value")
		let attributeWrapper = "AttributeWrapper" --> t("[") <+> n("AttributeList") <+> t("]") <|> n("AttributeWrapper") <+> n("W") <|> n("W") <+> n("AttributeWrapper")
		let attributeList = "AttributeList" --> n("Attribute") <|> n("Attribute") <+> n("AttributeList") <|> [[]]
		let attribute = "Attribute" --> n("Value") <+> t("=") <+> n("Value")
		productions += node + attribute + attributeWrapper + attributeList
		
		let edge = "Edge" --> n("Value") <+> n("EdgeType") <+> n("Value") <|> n("Value") <+> n("EdgeType") <+> n("Value") <+> n("AttributeWrapper")
		let edgeType = "EdgeType" --> t("->") <|> t("--")
		productions += edge + edgeType
		
		let subgraph = "Subgraph" --> n("GraphContentWrap") <|> n("W") <+> n("Subgraph") <|> n("Subgraph") <+> n("W")
		productions += subgraph
		
		return Grammar(productions: productions, start: "Graph")
	}
	
	private var expressionGrammar: Grammar {
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
		let Num = try! "Num" --> re("\\b\\d+(\\.\\d+)?\\b")
		let Var = try! "Var" --> re("\\b[a-zA-Z_][a-zA-Z0-9_]*\\b")
		let Whitespace = try! "Whitespace" --> re("\\s+")
		
		return Grammar(productions: expression + BinOp + UnOp + Num + Var + BracketExpr + BinOperation + UnOperation + Whitespace, start: "Expr")
	}

	private var someTree: SyntaxTree<Int, String> = {
		var tree = SyntaxTree<Int, String>.node(key: 0, children: [
			.node(key: 10, children: [
				.node(key: 20, children: [
					.node(key: 30, children: [
						.leaf("Leaft 40"),
					]),
				]),
				.node(key: 21, children: [
					.node(key: 31, children: [
						.leaf("Leaft 41"),
						.leaf("Leaft 42"),
						.leaf("Leaft 43"),
						.leaf("Leaft 44"),
						.leaf("Leaft 45"),
					]),
					.node(key: 32, children: [
						.leaf("Leaft 46"),
						.leaf("Leaft 47"),
					]),
				]),
				.node(key: 22, children: [
					.leaf("Leaft 30"),
					.node(key: 33, children: [

					]),
				]),
			]),
			.node(key: 11, children: [
				.leaf("leaf 20")
			]),
			.node(key: 12, children: [

			]),
			.node(key: 13, children: [
				.node(key: 23, children: [
					.leaf("Leaft 31"),
					.leaf("Leaft 32"),
				]),
			]),
		])

		return tree
	}()
	
	func testTreeDescription() throws {
		let testString = "((-baz-fooBar)/hello)"
		let tree = try EarleyParser(grammar: expressionGrammar).syntaxTree(for: testString).mapLeafs{String(testString[$0])}
		let description = tree.description
		XCTAssertTrue(CYKParser(grammar: dotGrammar).recognizes(description))
	}

    static var allTests = [
        ("testTreeDescription", testTreeDescription)
    ]
}
