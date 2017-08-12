//
//  ProductionTests.swift
//  CovfefeTests
//
//  Created by Palle Klewitz on 11.08.17.
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

class ProductionTests: XCTestCase {
	
	func testDecomposition() {
		let production = "A" --> n("B") <+> n("C") <+> n("D")
		
		let decomposed = Grammar.decomposeProductions(productions: [production])
		guard decomposed.count == 2 else {
			XCTFail()
			return
		}
		XCTAssertTrue(decomposed.contains("A" --> n("B") <+> n("A_C1")))
		XCTAssertTrue(decomposed.contains("A_C1" --> n("C") <+> n("D")))
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
	
	func testNormalization() {
		Grammar(productions: ["A" --> n("C"), "B" --> n("D")], start: "A")
	}
}
