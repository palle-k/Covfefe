//
//  EarleyParser.swift
//  Covfefe
//
//  Created by Palle Klewitz on 27.08.17.
//

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
		
		for (tokenIndex, tokens) in tokenization.enumerated() {
			let nextStateIndex = tokenIndex + 1
			
			
		}
		
		fatalError()
	}
}
