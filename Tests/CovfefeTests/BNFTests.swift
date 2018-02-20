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
	
	func testUnicodeScalars() throws {
		let grammarString = """
		<s> ::= "\\u{0020}"
		"""
		let grammar = try Grammar(bnfString: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes(" "))
		
		XCTAssertFalse(parser.recognizes(""))
		XCTAssertFalse(parser.recognizes("  "))
		
		// Disallow empty unicode scalars
		XCTAssertThrowsError(try Grammar(bnfString: "<s> ::= '\\u{}'", start: "s"))
		
		// Disallow too long unicode scalars
		XCTAssertThrowsError(try Grammar(bnfString: "<s> ::= '\\u{000000001}'", start: "s"))
		
		// Disallow invalid unicode scalars
		XCTAssertThrowsError(try Grammar(bnfString: "<s> ::= '\\u{d800}'", start: "s"))
	}
	
	func testEscaped() throws {
		let grammarString = """
		<s> ::= "\\r" "\\n" | "\\r" | "\\n" | "\\t" | "\\\\" | "\\\"" | '\\''
		"""
		let grammar = try Grammar(bnfString: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("\r\n"))
		XCTAssertTrue(parser.recognizes("\r\n"))
		XCTAssertTrue(parser.recognizes("\r"))
		XCTAssertTrue(parser.recognizes("\n"))
		XCTAssertTrue(parser.recognizes("\t"))
		XCTAssertTrue(parser.recognizes("\\"))
		XCTAssertTrue(parser.recognizes("\""))
		XCTAssertTrue(parser.recognizes("'"))
		
		XCTAssertFalse(parser.recognizes("\n\r"))
		XCTAssertFalse(parser.recognizes("\t\r"))
		XCTAssertFalse(parser.recognizes(" "))
		XCTAssertFalse(parser.recognizes(""))
		XCTAssertFalse(parser.recognizes("\\\\"))
		XCTAssertFalse(parser.recognizes("\"\""))
		XCTAssertFalse(parser.recognizes("''"))
	}
	
	func testEmpty() {
		XCTAssertNoThrow(try Grammar(bnfString: "", start: "s"))
		XCTAssertNoThrow(try Grammar(bnfString: "\n", start: "s"))
		XCTAssertEqual((try? Grammar(bnfString: "", start: "s"))?.productions.count, 0)
	}
	
	func testComments() throws {
		// Positioning
		XCTAssertNoThrow(try Grammar(bnfString: "<s> ::= 'x' (* hello world *)", start: "s"))
		XCTAssertNoThrow(try Grammar(bnfString: "<s> ::= (* hello world *) 'x'", start: "s"))
		XCTAssertNoThrow(try Grammar(bnfString: "<s> (* hello world *) ::= 'x'", start: "s"))
		XCTAssertNoThrow(try Grammar(bnfString: "(* hello world *) <s> ::= 'x'", start: "s"))
		XCTAssertNoThrow(try Grammar(bnfString: "<s> ::= 'x' (* hello world *) 'y'", start: "s"))
		XCTAssertNoThrow(try Grammar(bnfString: "<s> ::= 'x' \n (* hello world *)", start: "s"))

		// Empty comments
		XCTAssertNoThrow(try Grammar(bnfString: "<s> ::= 'x' (**)", start: "s"))
		
		// Nested comments
		XCTAssertNoThrow(try Grammar(bnfString: "(* (* hello *) world *) <s> ::= 'x'", start: "s"))
		XCTAssertNoThrow(try Grammar(bnfString: "(* (* hello (**) *) world *) <s> ::= 'x'", start: "s"))
		XCTAssertNoThrow(try Grammar(bnfString: "(* * *)", start: "s"))
		XCTAssertNoThrow(try Grammar(bnfString: "(* ( *)", start: "s"))
		XCTAssertNoThrow(try Grammar(bnfString: "(* ) *)", start: "s"))
		
		// Rules
		XCTAssertEqual((try? Grammar(bnfString: "(* *)", start: "s"))?.productions.count, 0)
		
		// Invalid comments
		XCTAssertThrowsError(try Grammar(bnfString: "(* hello", start: "s"))
		XCTAssertThrowsError(try Grammar(bnfString: "<s> ::= 'x' *)", start: "s"))
		XCTAssertThrowsError(try Grammar(bnfString: "<s> ::= 'x' (* (* *)", start: "s"))
		XCTAssertThrowsError(try Grammar(bnfString: "<s> ::= (* (* *) 'x'", start: "s"))
		XCTAssertThrowsError(try Grammar(bnfString: "<s> ::= 'x' (* *) *)", start: "s"))
	}
	
	func testCharacterRangeParsing() throws {
		let validExamples = [
			"<s> ::= 'a' ... 'b'",
			"<s> ::= 'a'...'b'",
			"<s> ::= 'a' ...'b'",
			"<s> ::= 'a'... 'b'",
			"<s> ::= \"a\" ... 'b'",
			"<s> ::= \"a\" ... \"b\"",
		]
		
		let invalidExamples = [
			"<s> ::= 'b'... 'a'",
			"<s> ::= 'a...'b'",
			"<s> ::= 'aa'...'b'",
			"<s> ::= '0'...'10'",
		]
		
		for validExample in validExamples {
			XCTAssertNoThrow(try Grammar(bnfString: validExample, start: "s"))
		}
		
		for invalidExample in invalidExamples {
			print(invalidExample)
			XCTAssertThrowsError(try Grammar(bnfString: invalidExample, start: "s"))
		}
	}
	
	func testCharacterRanges() throws {
		let grammarString = """
		<s> ::= 'a' ... 'z'
		"""
		let grammar = try Grammar(bnfString: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		for c in ["a", "b", "x", "y", "z"] {
			print(c)
			XCTAssertTrue(parser.recognizes(c))
		}
		
		for c in ["A", "Z", "aa", "bb"] {
			XCTAssertFalse(parser.recognizes(c))
		}
	}
	
	func testBNFExport() throws {
		let samples = [
			"<s> ::= '\\r'",
			"<s> ::= '\\n'",
			"<s> ::= '\\t'",
			"<s> ::= '\\\\'",
			"<s> ::= '\\u{20}'",
			"<s> ::= '\\''",
			"<s> ::= '\\'\"'",
			"<s> ::= \"\\\"\"",
			"<s> ::= \"\\\"'\"",
		]
		
		for grammarString in samples {
			let referenceGrammar = try Grammar(bnfString: grammarString, start: "s")
			
			let encodedString = referenceGrammar.description
			let decodedGrammar = try Grammar(bnfString: encodedString, start: "s")
			
			XCTAssertEqual(referenceGrammar, decodedGrammar)
		}
	}
}
