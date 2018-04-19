//
//  XCTestManifests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 19.04.18.
//

import Foundation

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
	return [
		testCase(AmbiguousGrammarTests.allTests),
		testCase(BNFTests.allTests),
		testCase(EarleyParserTests.allTests),
		testCase(EBNFTests.allTests),
		testCase(GrammarTests.allTests),
		testCase(ParserTests.allTests),
		testCase(PerformanceTests.allTests),
		testCase(PrefixGrammarTests.allTests),
		testCase(ProductionTests.allTests),
		testCase(StringUtilitiesTest.allTests),
		testCase(SyntaxTreeTests.allTests)
	]
}
#endif
