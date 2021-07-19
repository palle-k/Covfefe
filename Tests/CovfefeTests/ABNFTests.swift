//
//  File.swift
//  
//
//  Created by Palle Klewitz on 23.05.20.
//  Copyright (c) 2020 Palle Klewitz
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
import Covfefe
import XCTest


class ABNFTests: XCTestCase {
    func testGrammarExamples() throws {
        let testStrings = [
            """
            root = hello world
            """,
            "root = a",
            """
            root = hello world
            root =/ a / b
            """,
            """
            root = a ; trailing comment
            """,
            """
            root = %x0a %xA0 ; hex literals
            root = %d99 ; decimal liteerals
            """,
            """
            root = %xaa.bb.cc ; hex sequences
            """,
            """
            root = %d77.78.79 ; decimal sequences
            """,
            """
            root = %x00-42 ; hex range
            """,
            """
            root = %d00-42 ; integer range
            """,
            "",
            "; only comment", // only comment
            """
            root = 2*4repeat
            root =/ 2*4"literal"
            root =/ *4%x42
            root =/ 4*%d12
            root =/ *(hello world)
            root =/ 8repeat
            """,
            """
            root = [optional]
            """
        ]
        
        for example in testStrings {
            do {
                _ = try Grammar(abnf: example, start: "root")
            } catch {
                print(error)
                XCTFail(example)
            }
        }
    }
    
    func testIncorrectExamples() {
        let testStrings = [
            "root =",
            "= hello",
            "root = ; hello",
            "root = test = hello",
            "root = %x42-40 ; invalid range",
            "root = %d298423985729328 ; invalid unicode scalar",
            "root = %dFF ; hex instead of decimal",
            "root = %xG ; invalid hexadecimal",
            "root = 4*2hello ; invalid range"
        ]
        for example in testStrings {
            do {
                let grammar = try Grammar(abnf: example, start: "root")
                print(grammar.ebnf)
                XCTFail("Error expected for \(example)")
            } catch {}
        }
    }
    
    func testConcat() throws {
        let grammar = try Grammar(abnf: "root = \"a\" \"b\"", start: "root")
        let parser = EarleyParser(grammar: grammar)
        XCTAssertTrue(parser.recognizes("ab"))
        XCTAssertFalse(parser.recognizes("b"))
        XCTAssertFalse(parser.recognizes("a"))
        XCTAssertFalse(parser.recognizes("aa"))
        XCTAssertFalse(parser.recognizes(""))
    }
    
    func testAlternation() throws {
        let grammar = try Grammar(abnf: "root = \"a\" / \"b\"", start: "root")
        let parser = EarleyParser(grammar: grammar)
        XCTAssertTrue(parser.recognizes("a"))
        XCTAssertTrue(parser.recognizes("b"))
        XCTAssertFalse(parser.recognizes("ab"))
        XCTAssertFalse(parser.recognizes(""))
    }
    
    func testRange1() throws {
        let grammar = try Grammar(abnf: "root = 3\"a\"", start: "root")
        let parser = EarleyParser(grammar: grammar)
        XCTAssertTrue(parser.recognizes("aaa"))
        XCTAssertFalse(parser.recognizes("aaaa"))
        XCTAssertFalse(parser.recognizes("aa"))
    }
    
    func testRange2() throws {
        let grammar = try Grammar(abnf: "root = *3\"a\"", start: "root")
        let parser = EarleyParser(grammar: grammar)
        XCTAssertTrue(parser.recognizes("aaa"))
        XCTAssertFalse(parser.recognizes("aaaa"))
        XCTAssertTrue(parser.recognizes("aa"))
        XCTAssertTrue(parser.recognizes("a"))
        XCTAssertTrue(parser.recognizes(""))
    }
    
    func testRange3() throws {
        let grammar = try Grammar(abnf: "root = 3*\"a\"", start: "root")
        let parser = EarleyParser(grammar: grammar)
        XCTAssertTrue(parser.recognizes("aaa"))
        XCTAssertFalse(parser.recognizes("aa"))
        XCTAssertFalse(parser.recognizes(""))
        XCTAssertTrue(parser.recognizes("aaaa"))
        XCTAssertTrue(parser.recognizes("aaaaaaaaaaaaa"))
    }
    
    func testRange4() throws {
        let grammar = try Grammar(abnf: "root = *\"a\"", start: "root")
        let parser = EarleyParser(grammar: grammar)
        XCTAssertTrue(parser.recognizes("aaa"))
        XCTAssertTrue(parser.recognizes("aa"))
        XCTAssertTrue(parser.recognizes(""))
        XCTAssertTrue(parser.recognizes("aaaa"))
        XCTAssertTrue(parser.recognizes("aaaaaaaaaaaaa"))
        XCTAssertFalse(parser.recognizes("b"))
    }
    
    func testOptional() throws {
        let grammar = try Grammar(abnf: "root = [\"a\"]", start: "root")
        let parser = EarleyParser(grammar: grammar)
        XCTAssertTrue(parser.recognizes("a"))
        XCTAssertTrue(parser.recognizes(""))
        XCTAssertFalse(parser.recognizes("b"))
        XCTAssertFalse(parser.recognizes("aa"))
    }
    
    func testNesting1() throws {
        let grammar = try Grammar(abnf: "root = \"a\" (\"b\" / \"c\") \"d\"", start: "root")
        let parser = EarleyParser(grammar: grammar)
        XCTAssertTrue(parser.recognizes("abd"))
        XCTAssertTrue(parser.recognizes("acd"))
        XCTAssertFalse(parser.recognizes("ad"))
        XCTAssertFalse(parser.recognizes("abcd"))
    }
    
    func testNesting2() throws {
        let grammar = try Grammar(abnf: "root = \"a\" 2(\"b\" / \"c\") \"d\"", start: "root")
        let parser = EarleyParser(grammar: grammar)
        XCTAssertTrue(parser.recognizes("abbd"))
        XCTAssertTrue(parser.recognizes("accd"))
        XCTAssertFalse(parser.recognizes("abd"))
        XCTAssertTrue(parser.recognizes("abcd"))
    }
    
    func testABNFExport() throws {
        let testStrings = [
            """
            root = hello world
            """,
            "root = a",
            """
            root = hello world
            root =/ a / b
            """,
            """
            root = a ; trailing comment
            """,
            """
            root = %x0a %xA0 ; hex literals
            root = %d99 ; decimal liteerals
            """,
            """
            root = %xaa.bb.cc ; hex sequences
            """,
            """
            root = %d77.78.79 ; decimal sequences
            """,
            """
            root = %x00-42 ; hex range
            """,
            """
            root = %d00-42 ; integer range
            """,
            "",
            "; only comment", // only comment
            """
            root = 2*4repeat
            root =/ 2*4"literal"
            root =/ *4%x42
            root =/ 4*%d12
            root =/ *(hello world)
            root =/ 8repeat
            """,
            """
            root = [optional]
            """
        ]
        for example in testStrings {
            let grammar = try Grammar(abnf: example, start: "root")
            do {
                _ = try Grammar(abnf: grammar.abnf, start: "root")
            } catch {
                XCTFail()
            }
        }
    }
    
    static var allTests = [
        ("testGrammarExamples", testGrammarExamples),
		("testIncorrectExamples", testIncorrectExamples),
		("testConcat", testConcat),
		("testAlternation", testAlternation),
		("testRange1", testRange1),
		("testRange2", testRange2),
		("testRange3", testRange3),
		("testRange4", testRange4),
		("testOptional", testOptional),
		("testNesting1", testNesting1),
		("testNesting2", testNesting2),
		("testABNFExport", testABNFExport),
    ]
}
