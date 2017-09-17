//
//  AmbiguousGrammarTests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 17.09.17.
//

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
                bnfString: """
                <expression> ::= <expression> '+' <expression> | 'a'
                """,
                start: "expression"
            ),
            tests: [
                ("a+a", 1),
                ("a+a+a", 2),
                ("a+a+a+a", 5) // ((a+a)+a)+a, ((a+a)+(a+a)), a+(a+(a+a)), (a+(a+a))+a, a+((a+a)+a)
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
