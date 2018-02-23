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
		let grammar = try Grammar(bnf: grammarString, start: "hello")
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
		let grammar = try Grammar(bnf: grammarString, start: "s")
		XCTAssertEqual(grammar.description, grammarString)
		XCTAssertTrue(grammar.productions.contains("s" --> t("'")))
		XCTAssertTrue(grammar.productions.contains("s" --> t("\"")))
	}
	
	func testUnicodeScalars() throws {
		let grammarString = """
		<s> ::= "\\u{0020}"
		"""
		let grammar = try Grammar(bnf: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes(" "))
		
		XCTAssertFalse(parser.recognizes(""))
		XCTAssertFalse(parser.recognizes("  "))
		
		// Disallow empty unicode scalars
		XCTAssertThrowsError(try Grammar(bnf: "<s> ::= '\\u{}'", start: "s"))
		
		// Disallow too long unicode scalars
		XCTAssertThrowsError(try Grammar(bnf: "<s> ::= '\\u{000000001}'", start: "s"))
		
		// Disallow invalid unicode scalars
		XCTAssertThrowsError(try Grammar(bnf: "<s> ::= '\\u{d800}'", start: "s"))
	}
	
	func testEscaped() throws {
		let grammarString = """
		<s> ::= "\\r" "\\n" | "\\r" | "\\n" | "\\t" | "\\\\" | "\\\"" | '\\''
		"""
		let grammar = try Grammar(bnf: grammarString, start: "s")
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
		XCTAssertNoThrow(try Grammar(bnf: "", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "\n", start: "s"))
		XCTAssertEqual((try? Grammar(bnf: "", start: "s"))?.productions.count, 0)
	}
	
	func testComments() throws {
		// Positioning
		XCTAssertNoThrow(try Grammar(bnf: "<s> ::= 'x' (* hello world *)", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "<s> ::= (* hello world *) 'x'", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "<s> (* hello world *) ::= 'x'", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "(* hello world *) <s> ::= 'x'", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "<s> ::= 'x' (* hello world *) 'y'", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "<s> ::= 'x' \n (* hello world *)", start: "s"))

		// Empty comments
		XCTAssertNoThrow(try Grammar(bnf: "<s> ::= 'x' (**)", start: "s"))
		
		// Nested comments
		XCTAssertNoThrow(try Grammar(bnf: "(* (* hello *) world *) <s> ::= 'x'", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "(* (* hello (**) *) world *) <s> ::= 'x'", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "(* * *)", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "(* ( *)", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "(* ) *)", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "(***)", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "(****)", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "(*****)", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "(* (( *)", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "(* ((( *)", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "(* () *)", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "(* (a) *)", start: "s"))
		XCTAssertNoThrow(try Grammar(bnf: "(* (ab) *)", start: "s"))
		
		// Rules
		XCTAssertEqual((try? Grammar(bnf: "(* *)", start: "s"))?.productions.count, 0)
		
		// Invalid comments
		XCTAssertThrowsError(try Grammar(bnf: "(* hello", start: "s"))
		XCTAssertThrowsError(try Grammar(bnf: "<s> ::= 'x' *)", start: "s"))
		XCTAssertThrowsError(try Grammar(bnf: "<s> ::= 'x' (* (* *)", start: "s"))
		XCTAssertThrowsError(try Grammar(bnf: "<s> ::= (* (* *) 'x'", start: "s"))
		XCTAssertThrowsError(try Grammar(bnf: "<s> ::= 'x' (* *) *)", start: "s"))
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
			XCTAssertNoThrow(try Grammar(bnf: validExample, start: "s"))
		}
		
		for invalidExample in invalidExamples {
			XCTAssertThrowsError(try Grammar(bnf: invalidExample, start: "s"))
		}
	}
	
	func testCharacterRanges() throws {
		let grammarString = """
		<s> ::= 'a' ... 'z'
		"""
		let grammar = try Grammar(bnf: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		for c in ["a", "b", "x", "y", "z"] {
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
			"<s> ::= 'a' ... 'z'"
		]
		
		for grammarString in samples {
			let referenceGrammar = try Grammar(bnf: grammarString, start: "s")
			
			let encodedString = referenceGrammar.description
			let decodedGrammar = try Grammar(bnf: encodedString, start: "s")
			
			XCTAssertEqual(referenceGrammar, decodedGrammar)
		}
	}
	
	func testExpressionGroupParsing() {
		let validExamples = [
			"<s> ::= ('a')",
			"<s> ::= ('a' | 'b')",
			"<s> ::= ('a' 'b')",
			"<s> ::= ( 'a' 'b')",
			"<s> ::= ('a' 'b' )",
			"<s> ::= ('a''b' )",
			"<s> ::= (   'a''b' )",
			"<s> ::= ((('a')))",
		]
		
		let invalidExamples = [
			"<s> ::= ()",
			"<s> ::= ( )",
			"<s> ::= (",
			"<s> ::= )",
			"<s> ::= (()",
			"<s> ::= ('a'",
			"<s> ::= 'a')",
		]
		
		for validExample in validExamples {
			XCTAssertNoThrow(try Grammar(bnf: validExample, start: "s"))
		}
		
		for invalidExample in invalidExamples {
			XCTAssertThrowsError(try Grammar(bnf: invalidExample, start: "s"))
		}
	}
	
	func testExpressionGroups() throws {
		let grammarString = """
		<s> ::= ('a' | 'b') 'c'
		"""
		let grammar = try Grammar(bnf: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("ac"))
		XCTAssertTrue(parser.recognizes("bc"))
		
		XCTAssertFalse(parser.recognizes("aa"))
		XCTAssertFalse(parser.recognizes("bb"))
		XCTAssertFalse(parser.recognizes("cc"))
		XCTAssertFalse(parser.recognizes("a"))
		XCTAssertFalse(parser.recognizes("b"))
		XCTAssertFalse(parser.recognizes("c"))
		XCTAssertFalse(parser.recognizes("acc"))
		XCTAssertFalse(parser.recognizes("abc"))
		XCTAssertFalse(parser.recognizes("bbc"))
		XCTAssertFalse(parser.recognizes("aacc"))
	}
	
	func testExpressionGroups2() throws {
		let grammarString = """
		<s> ::= 'a' ('b' | 'c') ('d' | 'e') 'f'
		"""
		let grammar = try Grammar(bnf: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("abdf"))
		XCTAssertTrue(parser.recognizes("abef"))
		XCTAssertTrue(parser.recognizes("acdf"))
		XCTAssertTrue(parser.recognizes("acef"))
		
		XCTAssertFalse(parser.recognizes("accf"))
		XCTAssertFalse(parser.recognizes("addf"))
		XCTAssertFalse(parser.recognizes("adbf"))
		XCTAssertFalse(parser.recognizes("adbb"))
	}
	
	func testExpressionGroups3() throws {
		let grammarString = """
		<s> ::= 'd' ('a' 'b' | 'c')
		"""
		let grammar = try Grammar(bnf: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("dab"))
		XCTAssertTrue(parser.recognizes("dc"))
		
		XCTAssertFalse(parser.recognizes("dac"))
		XCTAssertFalse(parser.recognizes("dbc"))
		XCTAssertFalse(parser.recognizes("bc"))
		XCTAssertFalse(parser.recognizes("ab"))
	}
	
	func testExpressionGroups4() throws {
		let grammarString = """
		<s> ::= (('a' | 'b') ('c' | 'd')) (('a' | 'b') ('c' | 'd'))
		"""
		let grammar = try Grammar(bnf: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("acac"))
		XCTAssertTrue(parser.recognizes("adbd"))
		XCTAssertTrue(parser.recognizes("bcad"))
		XCTAssertTrue(parser.recognizes("bcbd"))
		
		XCTAssertFalse(parser.recognizes("abcd"))
		XCTAssertFalse(parser.recognizes("cbbd"))
		XCTAssertFalse(parser.recognizes("adaa"))
	}
	
	func testRepetitionGrammar() {
		let validExamples = [
			"<s> ::= {'a'}",
			"<s> ::= {'a' | 'b'}",
			"<s> ::= {'a' 'b'}",
			"<s> ::= { 'a' 'b'}",
			"<s> ::= {'a' 'b' }",
			"<s> ::= {'a''b' }",
			"<s> ::= {   'a''b' }",
			"<s> ::= {{{'a'}}}",
			]
		
		let invalidExamples = [
			"<s> ::= {}",
			"<s> ::= { }",
			"<s> ::= {",
			"<s> ::= }",
			"<s> ::= {{}",
			"<s> ::= {'a'",
			"<s> ::= 'a'}",
			]
		
		for validExample in validExamples {
			XCTAssertNoThrow(try Grammar(bnf: validExample, start: "s"))
		}
		
		for invalidExample in invalidExamples {
			XCTAssertThrowsError(try Grammar(bnf: invalidExample, start: "s"))
		}
	}
	
	func testRepetition() throws {
		let grammarString = """
		<s> ::= {'a'}
		"""
		let grammar = try Grammar(bnf: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("a"))
		XCTAssertTrue(parser.recognizes("aa"))
		XCTAssertTrue(parser.recognizes("aaaaaaaaaaaaaa"))
		
		XCTAssertFalse(parser.recognizes(""))
		XCTAssertFalse(parser.recognizes("b"))
		XCTAssertFalse(parser.recognizes("aaaaaaab"))
		XCTAssertFalse(parser.recognizes("baaaaaaa"))
	}
	
	func testRepetition2() throws {
		let grammarString = """
		<s> ::= {'a' 'b'}
		"""
		let grammar = try Grammar(bnf: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("ab"))
		XCTAssertTrue(parser.recognizes("ababab"))
		XCTAssertTrue(parser.recognizes("abababab"))
		
		XCTAssertFalse(parser.recognizes("b"))
		XCTAssertFalse(parser.recognizes("ba"))
		XCTAssertFalse(parser.recognizes("bababa"))
		XCTAssertFalse(parser.recognizes("abb"))
		XCTAssertFalse(parser.recognizes(""))
	}
	
	func testRepetition3() throws {
		let grammarString = """
		<s> ::= {'a' | 'b'}
		"""
		let grammar = try Grammar(bnf: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("a"))
		XCTAssertTrue(parser.recognizes("b"))
		XCTAssertTrue(parser.recognizes("aaababab"))
		XCTAssertTrue(parser.recognizes("baabababaaaa"))
		XCTAssertTrue(parser.recognizes("bbbbb"))
		XCTAssertTrue(parser.recognizes("aaaaa"))
		
		XCTAssertFalse(parser.recognizes(""))
		XCTAssertFalse(parser.recognizes("c"))
		XCTAssertFalse(parser.recognizes("caaaaaab"))
	}
	
	func testRepetition4() throws {
		let grammarString = """
		<s> ::= {'a' {'b' | 'c'} 'd' | 'e'}
		"""
		let grammar = try Grammar(bnf: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("abd"))
		XCTAssertTrue(parser.recognizes("acd"))
		XCTAssertTrue(parser.recognizes("e"))
		XCTAssertTrue(parser.recognizes("eeeeee"))
		XCTAssertTrue(parser.recognizes("abdabd"))
		XCTAssertTrue(parser.recognizes("acdacdacd"))
		XCTAssertTrue(parser.recognizes("eabdeacdeeeeabd"))
		XCTAssertTrue(parser.recognizes("abcbcbcbccccccde"))
		
		XCTAssertFalse(parser.recognizes("abc"))
		XCTAssertFalse(parser.recognizes("a"))
		XCTAssertFalse(parser.recognizes("ab"))
		XCTAssertFalse(parser.recognizes("ac"))
		XCTAssertFalse(parser.recognizes("ea"))
	}
	
	func testRepetition5() throws {
		let grammarString = """
		<s> ::= {'a'} {'b'}
		"""
		let grammar = try Grammar(bnf: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("ab"))
		XCTAssertTrue(parser.recognizes("aaaaaaaabbbbbbbb"))
		XCTAssertTrue(parser.recognizes("abb"))
		XCTAssertTrue(parser.recognizes("aab"))
		
		XCTAssertFalse(parser.recognizes("ba"))
		XCTAssertFalse(parser.recognizes("baa"))
		XCTAssertFalse(parser.recognizes("aba"))
		XCTAssertFalse(parser.recognizes("bab"))
	}
	
	func testOptionalGrammar() {
		let validExamples = [
			"<s> ::= ['a']",
			"<s> ::= [['a']]",
			"<s> ::= ['a' 'b']",
			"<s> ::= ['a' <x>]",
			"<s> ::= [<x>]",
			"<s> ::= [{<x>}]",
			"<s> ::= [{(<x> <y>)}]",
			]
		
		let invalidExamples = [
			"<s> ::= []",
			"<s> ::= [ ]",
			"<s> ::= [<a>",
			"<s> ::= <a>]",
			"<s> ::= [[<a>]",
			"<s> ::= [<a>]]",
			]
		
		for validExample in validExamples {
			XCTAssertNoThrow(try Grammar(bnf: validExample, start: "s"))
		}
		
		for invalidExample in invalidExamples {
			XCTAssertThrowsError(try Grammar(bnf: invalidExample, start: "s"))
		}
	}
	
	func testOptional() throws {
		let grammarString = """
		<s> ::= 'a' ['b'] 'c'
		"""
		let grammar = try Grammar(bnf: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("abc"))
		XCTAssertTrue(parser.recognizes("ac"))
		
		XCTAssertFalse(parser.recognizes("abbc"))
		XCTAssertFalse(parser.recognizes("ab"))
		XCTAssertFalse(parser.recognizes("bc"))
		XCTAssertFalse(parser.recognizes("acc"))
		XCTAssertFalse(parser.recognizes("aac"))
	}
	
	func testOptional2() throws {
		let grammarString = """
		<s> ::= 'a' [{'b'}] 'c'
		"""
		let grammar = try Grammar(bnf: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes("ac"))
		XCTAssertTrue(parser.recognizes("abc"))
		XCTAssertTrue(parser.recognizes("abbbbc"))
		
		XCTAssertFalse(parser.recognizes("ab"))
		XCTAssertFalse(parser.recognizes("bc"))
		XCTAssertFalse(parser.recognizes("acc"))
		XCTAssertFalse(parser.recognizes("aac"))
	}
	
	func testOptional3() throws {
		let grammarString = """
		<s> ::= ['a' | 'b'] ['c' 'd'] ['e' ['f'] 'g']
		"""
		let grammar = try Grammar(bnf: grammarString, start: "s")
		let parser = EarleyParser(grammar: grammar)
		
		XCTAssertTrue(parser.recognizes(""))
		XCTAssertTrue(parser.recognizes("a"))
		XCTAssertTrue(parser.recognizes("b"))
		XCTAssertTrue(parser.recognizes("cd"))
		XCTAssertTrue(parser.recognizes("eg"))
		XCTAssertTrue(parser.recognizes("efg"))
		XCTAssertTrue(parser.recognizes("aeg"))
		XCTAssertTrue(parser.recognizes("beg"))
		XCTAssertTrue(parser.recognizes("bcdeg"))
		
		XCTAssertFalse(parser.recognizes("ab"))
		XCTAssertFalse(parser.recognizes("ace"))
		XCTAssertFalse(parser.recognizes("acefg"))
		XCTAssertFalse(parser.recognizes("aceg"))
		XCTAssertFalse(parser.recognizes("bceg"))
		XCTAssertFalse(parser.recognizes("bcde"))
		XCTAssertFalse(parser.recognizes("bcdfg"))
	}
}
