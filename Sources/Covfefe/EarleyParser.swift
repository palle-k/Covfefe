//
//  EarleyParser.swift
//  Covfefe
//
//  Created by Palle Klewitz on 27.08.17.
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

/// Represents a partial parse of a production
fileprivate struct ParseState {
	/// The partially parsed production
	let production: Production
	
	/// The index of the next symbol to be parsed
	var productionPosition: Int
	
	/// The index of the first token parsed in this partial parse
	let startTokenIndex: Int
}

extension ParseState: Hashable {
	static func ==(lhs: ParseState, rhs: ParseState) -> Bool {
		return lhs.production == rhs.production
			&& lhs.productionPosition == rhs.productionPosition
			&& lhs.startTokenIndex == rhs.startTokenIndex
	}
	
	var hashValue: Int {
		return production.hashValue ^ productionPosition.hashValue ^ (startTokenIndex.hashValue << 32) ^ (startTokenIndex.hashValue >> 32)
	}
}

struct EarleyParser: Parser {
	let grammar: Grammar
	
	init(grammar: Grammar) {
		self.grammar = grammar
	}
	
	func syntaxTree(for tokenization: [[(terminal: Terminal, range: Range<String.Index>)]]) throws -> SyntaxTree<NonTerminal, Range<String.Index>> {
		
		var stateCollection: [Set<ParseState>] = []
		stateCollection.reserveCapacity(tokenization.count+1)
		
		let nonTerminalProductions = Dictionary(grouping: grammar.productions, by: {$0.pattern})
		
		stateCollection.append(nonTerminalProductions[grammar.start, default: []].map({ (production) -> ParseState in
			ParseState(production: production, productionPosition: 0, startTokenIndex: 0)
		}).collect(Set.init))
		
		for index in 0 ... tokenization.count {
//			let nextStateIndex = tokenIndex + 1
			
			var currentStateRemaining = stateCollection[index]
			var currentStateDone: Set<ParseState> = []
			
			while let first = currentStateRemaining.popFirst() {
				currentStateDone.insert(first)
				
				guard first.production.production.count > first.productionPosition else {
					continue
				}
				
			}
			
			stateCollection[index] = currentStateDone
		}
		
		fatalError()
	}
}
