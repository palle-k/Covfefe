//
//  ParserTests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 13.09.17.
//

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
		)
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
