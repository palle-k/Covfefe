import XCTest
@testable import CovfefeTests

XCTMain([
    testCase(ABNFTests.allTests),
    testCase(AmbiguousGrammarTests.allTests),
    testCase(BNFTests.allTests),
    testCase(CYKParserTests.allTests),
    testCase(EarleyParserTests.allTests),
    testCase(EBNFTests.allTests),
    testCase(ParserTests.allTests),
    testCase(PerformanceTests.allTests),
    testCase(PrefixGrammarTests.allTests),
    testCase(ProductionTests.allTests),
    testCase(SyntaxTreeTests.allTests),
    testCase(StringUtilitiesTest.allTests),
])
