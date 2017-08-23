//
//  BNFTests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 21.08.17.
//

import XCTest
@testable import Covfefe

class BNFTests: XCTestCase {
    
	func testImport() throws {
		let grammarString = """
		<hello> ::= "hello" <world> | "foo" "bar" "baz" | "xyz"
		<world> ::= "world"
		"""
		let grammar = try Grammar(bnfString: grammarString, start: "hello")
		XCTAssertEqual(grammar.description, grammarString)
		XCTAssertTrue(grammar.productions.contains("hello" --> t("hello") <+> n("world")))
		XCTAssertTrue(grammar.productions.contains("hello" --> t("foo") <+> t("bar") <+> t("baz")))
		XCTAssertTrue(grammar.productions.contains("hello" --> t("xyz")))
		XCTAssertTrue(grammar.productions.contains("world" --> t("world")))
	}
}
