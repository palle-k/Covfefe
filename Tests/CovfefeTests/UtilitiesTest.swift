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
		
		XCTAssertEqual(testedString.rangeOfPrefix(["world"], from: testedString.startIndex), testedString.range(of: "world"))
		XCTAssertEqual(testedString.rangeOfPrefix(["world"], from: testedString.index(of: "w")!), testedString.range(of: "world"))
		XCTAssertNotEqual(testedString.rangeOfPrefix(["world"], from: testedString.index(testedString.startIndex, offsetBy: 8)), testedString.range(of: "world"))
		
		XCTAssertFalse(testedString.hasPrefix(["world"], from: testedString.startIndex))
		XCTAssertTrue(testedString.hasPrefix(["world"], from: testedString.index(of: "w")!))
		XCTAssertFalse(testedString.hasPrefix(["world"], from: testedString.index(testedString.startIndex, offsetBy: 8)))
	}
	
}
