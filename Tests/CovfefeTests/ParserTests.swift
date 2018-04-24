//
//  ParserTests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 13.09.17.
//  Copyright (c) 2017 - 2018 Palle Klewitz
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

class ParserTests: XCTestCase {
	
	let parsers: [((Grammar) -> Parser, String)] = [
		(CYKParser.init, "CYK Parser"),
		(EarleyParser.init, "Earley Parser")
	]
	
	let testGrammars: [(grammar: Grammar, testCases: [(string: String, expected: Bool)])] = [
		(
			grammar: Grammar(productions: [], start: ""),
			testCases: [
				("", false), ("hello", false), (" ", false), ("-", false), ("\\", false)
			]
		),
		(
			grammar: Grammar(
				productions: [
					"start" --> t("hello") <+> t(" ") <+> t("world")
				],
				start: "start"
			),
			testCases: [
				("hello world", true),
				("hello", false),
				("world", false),
				("helloworld", false),
				("hello worldfoo", false),
				("barhello world", false),
				("hello baz world", false),
				("ello world", false),
				("", false)
			]
		),
		(
			grammar: Grammar(
				productions: ("S" --> (n("A") <+> n("B")) <|> (n("C") <+> n("D")) <|> (n("A") <+> n("T")) <|> (n("C") <+> n("U")) <|> (n("S") <+> n("S"))) + [
				"T" --> n("S") <+> n("B"),
				"U" --> n("S") <+> n("D"),
				"A" --> [t("(")],
				"B" --> [t(")")],
				"C" --> [t("{")],
				"D" --> [t("}")]
				],
				start: "S"
			),
			testCases: [
				("()", true),
				("{}", true),
				("((()))", true),
				("({()})", true),
				("(()){}{}", true),
				("", false),
				("(", false),
				("{", false),
				("((())", false),
				("(()))", false),
				("({()))", false)
			]
		),
		(
			grammar: Grammar(productions: "start" --> [[]], start: "start"),
			testCases: [
				("", true),
				("hello", false),
				("a", false),
				("-", false),
				("\\", false),
				("'", false)
			]
		),
	]
	
	func testAll() {
		for (grammar, testCases) in self.testGrammars {
			for parserType in self.parsers {
				let (parser, parserName) = (parserType.0(grammar), parserType.1)
				for (testString, expectedSuccess) in testCases {
					if expectedSuccess {
						XCTAssertTrue(parser.recognizes(testString), "\(parserName) incorrectly did not accept \(testString) with grammar\n\(grammar)")
					} else {
						XCTAssertFalse(parser.recognizes(testString), "\(parserName) incorrectly accepted \(testString) with grammar\n\(grammar)")
					}
				}
			}
		}
	}
}

extension ParserTests {
	static let allTests = [
		("testAll", testAll),
	]
}
