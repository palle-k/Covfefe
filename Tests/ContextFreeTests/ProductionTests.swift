//
//  ProductionTests.swift
//  ContextFreeTests
//
//  Created by Palle Klewitz on 11.08.17.
//

import XCTest
@testable import Grammar

class ProductionTests: XCTestCase {
	
	func testDecomposition() {
		let production = "A" --> n("B") <+> n("C") <+> n("D")
		
		let decomposed = Grammar.decomposeProductions(productions: [production])
		guard decomposed.count == 2 else {
			XCTFail()
			return
		}
		XCTAssertTrue(decomposed.contains("A" --> n("B") <+> n("A_1")))
		XCTAssertTrue(decomposed.contains("A_1" --> n("C") <+> n("D")))
	}
	
	func testChainElimination() {
		let pA = "A" --> n("B")
		let pB = "B" --> t("x")
		
		let eliminated = Grammar.eliminateChainProductions(productions: [pA, pB])
		guard eliminated.count == 2 else {
			XCTFail()
			return
		}
		XCTAssertTrue(eliminated.contains("A" --> t("x")))
		XCTAssertTrue(eliminated.contains("B" --> t("x")))
		
		let pA2 = "A" --> n("A") <|> t("x")
		let eliminated2 = Grammar.eliminateChainProductions(productions: pA2).uniqueElements().collect(Array.init)
		print(eliminated2)
		guard eliminated2.count == 1 else {
			XCTFail()
			return
		}
		XCTAssertTrue(eliminated2.contains("A" --> t("x")))
	}
	
	func testEmptyElimination() {
		let pA = "A" --> t("x") <|> [[]] <|> n("A")
		let eliminated = Grammar.eliminateEmptyProductions(productions: pA, start: "SomethingElse")
		
		guard eliminated.count == 2 else {
			XCTFail()
			print(eliminated)
			return
		}
		XCTAssertTrue(eliminated.contains("A" --> t("x")))
	}
}
