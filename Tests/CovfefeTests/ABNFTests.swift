//
//  File.swift
//  
//
//  Created by Palle Klewitz on 23.05.20.
//  Copyright (c) 2020 Palle Klewitz
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
import Covfefe
import XCTest


class ABNFTests: XCTestCase {
    func testABNFParser() throws {
        let testStr = """
        postal-address   = name-part street zip-part

        name-part        = *(personal-part SP) last-name [SP suffix] CRLF
        name-part        =/ personal-part CRLF

        personal-part    = first-name / (initial ".")
        first-name       = *ALPHA
        initial          = ALPHA
        last-name        = *ALPHA
        suffix           = ("Jr." / "Sr." / 1*("I" / "V" / "X"))

        street           = [apt SP] house-num SP street-name CRLF
        apt              = 1*4DIGIT
        house-num        = 1*8(DIGIT / ALPHA)
        street-name      = 1*VCHAR

        zip-part         = town-name "," SP state 1*2SP zip-code CRLF
        town-name        = 1*(ALPHA / SP)
        state            = 2ALPHA
        zip-code         = 5DIGIT ["-" 4DIGIT]
        """
        
        print(try Grammar(abnf: testStr, start: "postal-address").ebnf)
    }
}
