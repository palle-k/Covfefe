//
//  SyntaxTreeTests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 13.08.17.
//

import Foundation
import XCTest
@testable import Covfefe

class SyntaxTreeTests: XCTestCase {
	private var dotGrammar: Grammar {
		var productions: [Production] = []
		
		let whitespace = try! "W" --> rt("\\s+")
		let anyIdentifier = try! "Identifier" --> rt("\\b[a-zA-Z_][a-zA-Z0-9_]+\\b")
		let anyString = try! "String" --> rt("\"[^\"]*\"")
		let value = "Value" --> n("Identifier") <|> n("String") <|> n("W") <+> n("Value") <|> n("Value") <+> n("W")
		productions += [whitespace, anyIdentifier, anyString] + value
		
		let graphType = try! "Type" --> rt("\\bdigraph\\b") <|> rt("\\bgraph\\b")
		let digraph = "Graph" --> n("Type") <+> n("W") <+> n("GraphContentWrap") <|> n("Type") <+> n("GraphContentWrap")
		let contentWrapper = "GraphContentWrap" --> t("{") <+> n("C") <+> t("}")
		let content = "C" --> n("C") <+> n("C") <|> n("Node") <|> n("Edge") <|> n("Subgraph") <|> n("Attribute")
		productions += digraph + [contentWrapper] + content + graphType
		
		let node = "Node" --> n("Value") <+> n("W") <+> n("AttributeWrapper") <|> n("Value") <+> n("AttributeWrapper") <|> n("Value")
		let attributeWrapper = "AttributeWrapper" --> t("[") <+> n("AttributeList") <+> t("]") <|> n("AttributeWrapper") <+> n("W") <|> n("W") <+> n("AttributeWrapper")
		let attributeList = "AttributeList" --> n("Attribute") <|> n("Attribute") <+> n("AttributeList") <|> [[]]
		let attribute = "Attribute" --> n("Value") <+> t("=") <+> n("Value")
		productions += node + [attribute] + attributeWrapper + attributeList
		
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
		let Num = try! "Num" --> rt("\\b\\d+(\\.\\d+)?\\b")
		let Var = try! "Var" --> rt("\\b[a-zA-Z_][a-zA-Z0-9_]*\\b")
		let Whitespace = try! "Whitespace" --> rt("\\s+")
		
		return Grammar(productions: expression + BinOp + UnOp + [Num, Var, BracketExpr, BinOperation, UnOperation, Whitespace], start: "Expr")
	}
	
	func testTreeDescription() throws {
		let testString = "((-baz-fooBar)/hello)"
		let tree = try! CYKParser(grammar: expressionGrammar).syntaxTree(for: testString).mapLeafs{String(testString[$0])}
		let description = tree.description
		XCTAssertTrue(CYKParser(grammar: dotGrammar).recognizes(description))
	}
}
