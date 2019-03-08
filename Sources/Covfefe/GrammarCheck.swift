//
//  GrammarCheck.swift
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
	
	/// Non-terminals which cannot be reached from the start non-terminal
	var unreachableNonTerminals: Set<NonTerminal> {
		let productionSet = productions.collect(Set.init)
		let reachableProductions = Grammar.eliminateUnusedProductions(productions: productions, start: start).collect(Set.init)
		return productionSet.subtracting(reachableProductions).map{$0.pattern}.collect(Set.init)
	}
	
	/// Nonterminals which can never produce a sequence of terminals
	/// because of infinite recursion.
	var unterminatedNonTerminals: Set<NonTerminal> {
		guard isInChomskyNormalForm else {
			return self.chomskyNormalized().unterminatedNonTerminals
		}
		let nonTerminalProductions = Dictionary(grouping: self.productions, by: {$0.pattern})
		return nonTerminalProductions.filter { _, prod -> Bool in
            return prod.allSatisfy {!$0.isFinal}
		}.keys.collect(Set.init)
	}
}

