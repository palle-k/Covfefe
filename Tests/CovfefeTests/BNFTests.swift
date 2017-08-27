//
//  BNFTests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 21.08.17.
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
	
	func testImportQuotes() throws {
		let grammarString = """
		<s> ::= "'" | '"'
		"""
		let grammar = try Grammar(bnfString: grammarString, start: "s")
		XCTAssertEqual(grammar.description, grammarString)
		XCTAssertTrue(grammar.productions.contains("s" --> t("'")))
		XCTAssertTrue(grammar.productions.contains("s" --> t("\"")))
	}
}
