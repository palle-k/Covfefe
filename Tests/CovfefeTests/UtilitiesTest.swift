//
//  UtilitiesTest.swift
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

import Foundation
import XCTest
@testable import Covfefe

class StringUtilitiesTest: XCTestCase {
	
	func testPrefix() {
		let testedString = "hello, world"
		
		XCTAssertEqual(testedString.rangeOfPrefix("world", from: testedString.startIndex), nil)
		XCTAssertEqual(testedString.rangeOfPrefix("world", from: testedString.firstIndex(of: "w")!), testedString.range(of: "world"))
		XCTAssertNotEqual(testedString.rangeOfPrefix("world", from: testedString.index(testedString.startIndex, offsetBy: 8)), testedString.range(of: "world"))
		
		XCTAssertFalse(testedString.hasPrefix("world", from: testedString.startIndex))
        XCTAssertTrue(testedString.hasPrefix("world", from: testedString.firstIndex(of: "w")!))
		XCTAssertFalse(testedString.hasPrefix("world", from: testedString.index(testedString.startIndex, offsetBy: 8)))
	}
	
	func testRegularPrefix() {
		let testedString = "1+2+3+4+5"
		
		XCTAssertTrue(try testedString.hasRegularPrefix("1\\+2"))
		XCTAssertTrue(try testedString.hasRegularPrefix("(\\d\\+)*\\d"))
		XCTAssertFalse(try testedString.hasRegularPrefix("\\+"))
		XCTAssertFalse(try testedString.hasRegularPrefix("\\d\\d"))
		XCTAssertFalse(try testedString.hasRegularPrefix("5"))
		
		XCTAssertNotNil(try testedString.rangeOfRegularPrefix("1\\+2"))
		XCTAssertNotNil(try testedString.rangeOfRegularPrefix("(\\d\\+)*\\d"))
		XCTAssertNil(try testedString.rangeOfRegularPrefix("\\+"))
		XCTAssertNil(try testedString.rangeOfRegularPrefix("\\d\\d"))
		XCTAssertNil(try testedString.rangeOfRegularPrefix("5"))
		
		XCTAssertEqual(try testedString.rangeOfRegularPrefix("1\\+2"), try testedString.matches(for: "1\\+2").first(where: {$0.lowerBound == testedString.startIndex}))
		XCTAssertEqual(try testedString.rangeOfRegularPrefix("(\\d\\+)*\\d"), try testedString.matches(for: "(\\d\\+)*\\d").first(where: {$0.lowerBound == testedString.startIndex}))
		XCTAssertEqual(try testedString.rangeOfRegularPrefix("\\+"), try testedString.matches(for: "\\+").first(where: {$0.lowerBound == testedString.startIndex}))
		XCTAssertEqual(try testedString.rangeOfRegularPrefix("\\d\\d"), try testedString.matches(for: "\\d\\d").first(where: {$0.lowerBound == testedString.startIndex}))
		XCTAssertEqual(try testedString.rangeOfRegularPrefix("5"), try testedString.matches(for: "5").first(where: {$0.lowerBound == testedString.startIndex}))
		
		let startIndex = testedString.index(testedString.startIndex, offsetBy: 2)
		
		XCTAssertTrue(try testedString.hasRegularPrefix("2", from: startIndex))
		XCTAssertTrue(try testedString.hasRegularPrefix("(\\d\\+)*\\d", from: startIndex))
		XCTAssertFalse(try testedString.hasRegularPrefix("\\+3", from: startIndex))
		XCTAssertFalse(try testedString.hasRegularPrefix("1", from: startIndex))
		
		XCTAssertEqual(try testedString.rangeOfRegularPrefix("2", from: startIndex), testedString.range(of: "2"))
		XCTAssertEqual(try testedString.rangeOfRegularPrefix("(\\d\\+)*\\d", from: startIndex), testedString.range(of: "2+3+4+5"))
	}
	
	func testCharacterRangePrefix() {
		let testedString = "hello world"
		
		XCTAssertTrue(testedString.hasPrefix(Terminal(range: "a" ... "z")))
		XCTAssertTrue(testedString.hasPrefix(Terminal(range: "h" ... "h")))
        XCTAssertTrue(testedString.hasPrefix(Terminal(range: "e" ... "e"), from: testedString.firstIndex(of: "e")!))
		
		XCTAssertFalse(testedString.hasPrefix(Terminal(range: "i" ... "i")))
		XCTAssertFalse(testedString.hasPrefix(Terminal(range: "A" ... "Z")))
        XCTAssertFalse(testedString.hasPrefix(Terminal(range: "f" ... "g"), from: testedString.firstIndex(of: "e")!))
		
		XCTAssertEqual(testedString.rangeOfPrefix(Terminal(range: "a" ... "z"), from: testedString.startIndex), testedString.startIndex ..< testedString.index(after: testedString.startIndex))
		XCTAssertEqual(testedString.rangeOfPrefix(Terminal(range: "z" ... "z"), from: testedString.startIndex), nil)
		
		XCTAssertEqual(testedString.rangeOfPrefix(Terminal(range: "e" ... "e"), from: testedString.index(after: testedString.startIndex)), testedString.index(after: testedString.startIndex) ..< testedString.index(testedString.startIndex, offsetBy: 2))
		XCTAssertEqual(testedString.rangeOfPrefix(Terminal(range: "z" ... "z"), from: testedString.startIndex), nil)
	}
	
	func testUnique() {
		let numbers = [1,2,2,1,5,6,7,1,1]
		let uniqueNumbers = numbers.uniqueElements().collect(Array.init)
		XCTAssertEqual(uniqueNumbers, [1,2,5,6,7])
	}
	
	func testCrossProduct() {
		let a = 1...4
		let b = 5...8
		let axb = crossProduct(a, b)
		let axbRef = [(1,5), (1,6), (1,7), (1,8), (2,5), (2,6), (2,7), (2,8), (3,5), (3,6), (3,7), (3,8), (4,5), (4,6), (4,7), (4,8)]
        XCTAssertTrue(axb.allSatisfy{el in axbRef.contains(where: {$0 == el})})
	}
	
	func testUnzip() {
		let aRef = Array(1...10)
		let bRef = Array(10...19)
		let (a, b): ([Int], [Int]) = unzip(zip(aRef,bRef))
		XCTAssertEqual(aRef, a)
		XCTAssertEqual(bRef, b)
	}

    static var allTests = [
        ("testPrefix", testPrefix),
        ("testRegularPrefix", testRegularPrefix),
        ("testCharacterRangePrefix", testCharacterRangePrefix),
        ("testUnique", testUnique),
        ("testCrossProduct", testCrossProduct),
        ("testUnzip", testUnzip),
    ]
}
