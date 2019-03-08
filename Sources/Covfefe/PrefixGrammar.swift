//
//  PrefixGrammar.swift
//  Covfefe
//
//  Created by Palle Klewitz on 16.08.17.
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

public extension Grammar {
	
	/// Generates a grammar which recognizes all prefixes of the original grammar.
	///
	/// For example if a grammar would generate `a*(b+c)`,
	/// the prefix grammar would generate the empty string, `a`, `a*`, `a*(`, `a*(b`
	/// `a*(b+` `a*(b+c` and `a*(b+c)`
	///
	/// - Returns: A grammar generating all prefixes of the original grammar
	func prefixGrammar() -> Grammar {
		let prefixProductions = productions.flatMap { (production) -> [Production] in
			let prefixes = production.production.prefixes().map { sequence -> [Symbol] in
				guard let last = sequence.last else {
					return sequence
				}
				guard case .nonTerminal(let nonTerminal) = last else {
					return sequence
				}
				return sequence.dropLast() + [.nonTerminal(NonTerminal(name: "\(nonTerminal.name)-pre"))]
			} + [[]]
			
			return prefixes.map {Production(pattern: NonTerminal(name: "\(production.pattern.name)-pre"), production: $0)}
		}
		let allProductions: [Production] = self.productions + prefixProductions + (NonTerminal(name: "\(self.start.name)-pre-start") --> n("\(self.start.name)-pre") <|> .nonTerminal(self.start))
		return Grammar(
			productions: allProductions.uniqueElements().collect(Array.init),
			start: NonTerminal(name: "\(self.start.name)-pre-start"),
			utilityNonTerminals: self.utilityNonTerminals
		)
	}
}
