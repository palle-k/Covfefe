//
//  AmbiguousGrammarTests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 17.09.17.
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

class AmbiguousGrammarTests: XCTestCase {
    
    let parsers: [((Grammar) -> AmbiguousGrammarParser, String)] = [
        (CYKParser.init, "CYK Parser"),
        (EarleyParser.init, "Earley Parser")
    ]
    
    let testCases: [(grammar: Grammar, tests: [(input: String, treeCount: Int)])] = [
        (
            grammar: try! Grammar(
                bnf: """
                <expression> ::= <expression> '+' <expression> | 'a'
                """,
                start: "expression"
            ),
            tests: [
                ("a+a", 1),
                ("a+a+a", 2),
                ("a+a+a+a", 5), // ((a+a)+a)+a, ((a+a)+(a+a)), a+(a+(a+a)), (a+(a+a))+a, a+((a+a)+a)
                ("a+a+a+a+a", 14)
                // Catalan numbers: 1, 2, 5, 14, 42, 132, 429, 1430, 4862, ...
            ]
        )
    ]
    
    func testAll() {
        for (grammar, tests) in testCases {
            for (parserGenerator, parserName) in parsers {
                let parser = parserGenerator(grammar)
                
                for (input, expectedCount) in tests {
                    XCTAssertEqual(expectedCount, try parser.allSyntaxTrees(for: input).count, "Expected \(expectedCount) syntax trees for expression \(input) with grammar \(grammar) parsed by \(parserName)")
                }
            }
        }
    }
}

extension AmbiguousGrammarTests {
	static let allTests = [
		("testAll", testAll)
	]
}
