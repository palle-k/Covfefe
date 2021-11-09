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


private let tree1: SyntaxTree<Int, String> = {
	.node(key: 1, children: [
		.node(key: 10, children: [
			.leaf("-10")
		]),
		.node(key: 11, children: [
			.node(key: 20, children: [
				.node(key: 30, children: [
					.leaf("-40"),
				]),
			]),
			.node(key: 21, children: [
				.node(key: 31, children: [
					.leaf("-41"),
					.leaf("-42"),
					.leaf("-43"),
					.leaf("-44"),
					.leaf("-45"),
				]),
				.node(key: 32, children: [
					.leaf("-46"),
					.leaf("-47"),
				]),
			]),
			.node(key: 22, children: [
				.leaf("-30"),
				.node(key: 33, children: [

				]),
			]),
		]),
		.node(key: 11, children: [
			.leaf("-20")
		]),
		.node(key: 12, children: [

		]),
		.node(key: 13, children: [
			.node(key: 23, children: [
				.leaf("-31"),
				.leaf("-32"),
			]),
		]),
	])
}()

private let tree2: SyntaxTree<String, Int> = {
	.node(key: "1", children: [
		.node(key: "10", children: [
			.leaf(-10)
		]),
		.node(key: "11", children: [
			.node(key: "20", children: [
				.node(key: "30", children: [
					.leaf(-40),
				]),
			]),
			.node(key: "21", children: [
				.node(key: "31", children: [
					.leaf(-41),
					.leaf(-42),
					.leaf(-43),
					.leaf(-44),
					.leaf(-45),
				]),
				.node(key: "32", children: [
					.leaf(-46),
					.leaf(-47),
				]),
			]),
			.node(key: "22", children: [
				.leaf(-30),
				.node(key: "33", children: [

				]),
			]),
		]),
		.node(key: "11", children: [
			.leaf(-20)
		]),
		.node(key: "12", children: [

		]),
		.node(key: "13", children: [
			.node(key: "23", children: [
				.leaf(-31),
				.leaf(-32),
			]),
		]),
	])
}()

private let tree3: SyntaxTree<String, Int> = {
	.node(key: "1", children: [
		.node(key: "11", children: [
			.node(key: "21", children: [
				.node(key: "31", children: [
					.leaf(-41),
					.leaf(-43),
					.leaf(-45),
				]),
			]),
		]),
		.node(key: "11", children: [
		]),
		.node(key: "13", children: [
			.node(key: "23", children: [
				.leaf(-31),
			]),
		]),
	])
}()

private let tree4: SyntaxTree<String, Int> = {
	.node(key: "0", children: [])
}()

private let tree5: SyntaxTree<String, Int> = {
	.leaf(0)
}()

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

	func testTreeDescription() throws {
		let testString = "((-baz-fooBar)/hello)"
		let tree = try EarleyParser(grammar: expressionGrammar).syntaxTree(for: testString).mapLeafs{String(testString[$0])}
		let description = tree.description
		XCTAssertTrue(CYKParser(grammar: dotGrammar).recognizes(description))
	}

	func testTreeMaps() {
		let invertedTree = tree1.map(String.init).mapLeafs { Int($0)! }

		XCTAssertTrue(invertedTree == tree2) 
	}

	func testTreeReduce() {
		let reduced: [Int] = tree1.reduce([]) { item, accumulator, _ in
			switch item {
			case .leaf(let leaf):
				accumulator.append(Int(leaf)!)
			case .node(let key, _):
				accumulator.append(key)
			}
		}
		let expected = [1, 10, -10, 11, 20, 30, -40, 21, 31, -41, -42, -43, -44, -45, 32, -46, -47, 22, -30, 33, 11, -20, 12, 13, 23, -31, -32]
		XCTAssertTrue(reduced == expected)

		XCTAssertTrue(tree4.reduce([]) { item, result, _ in result.append(item.root!)} == ["0"])
		XCTAssertTrue(tree5.reduce([]) { item, result, _ in result.append(item.leaf!)} == [0])
	}

	func testTreeFilter() {
		let filtered = tree2
			.filter { Int($0)! % 2 == 1 }!
			.filterLeafs { abs($0) % 2 == 1 }!

		XCTAssertTrue(filtered == tree3)

		XCTAssertTrue(tree4.filter { Int($0)! % 2 == 0 }!.root == "0")
		XCTAssertTrue(tree4.filter { Int($0)! % 2 == 1 } == nil )

		XCTAssertTrue(tree4.filterLeafs { $0 % 2 == 0 }!.root! == "0")
		XCTAssertTrue(tree4.filterLeafs { $0 % 2 == 1 }!.root! == "0")

		XCTAssertTrue(tree5.filter { Int($0)! % 2 == 0 }!.leaf! == 0)
		XCTAssertTrue(tree5.filter { Int($0)! % 2 == 1 }!.leaf! == 0)

		XCTAssertTrue(tree5.filterLeafs { $0 % 2 == 0 }!.leaf! == 0)
		XCTAssertTrue(tree5.filterLeafs { $0 % 2 == 1 } == nil )
	}

    static var allTests = [
        ("testTreeDescription", testTreeDescription),
		("testTreeMaps", testTreeMaps),
		("testTreeReduce", testTreeReduce),
		("testTreeFilter", testTreeFilter)
    ]
}
