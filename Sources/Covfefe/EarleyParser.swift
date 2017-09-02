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

extension ParseState {
	var isCompleted: Bool {
		return !production.production.indices.contains(productionPosition)
	}
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

extension ParseState: CustomStringConvertible {
	var description: String {
		let producedString = production.production.map { symbol -> String in
			switch symbol {
			case .nonTerminal(let nonTerminal):
				return "<\(nonTerminal.name)>"
				
			case .terminal(let terminal):
				return "\"\(terminal.value)\""
			}
		}.enumerated().reduce("") { (partialResult, string) in
			if string.offset == productionPosition {
				return partialResult.appending(" • \(string.element)")
			}
			return partialResult.appending(" \(string.element)")
		}
		if isCompleted {
			return "<\(production.pattern)> ::=\(producedString) • (\(startTokenIndex))"
		} else {
			return "<\(production.pattern)> ::=\(producedString) (\(startTokenIndex))"
		}
		
	}
}

/// A parser generator implementation that internally uses
/// the Earley algorithm.
///
/// Creates a syntax tree in O(n^3) worst case run time.
/// For unambiguous grammars, the run time is O(n^2).
/// For almost all LR(k) grammars, the run time is O(n).
/// Best performance can be achieved with left recursive grammars.
public struct EarleyParser: Parser {
	let grammar: Grammar
	
	/// Generates an earley parser for the given grammar.
	///
	/// Creates a syntax tree in O(n^3) worst case run time.
	/// For unambiguous grammars, the run time is O(n^2).
	/// For almost all LR(k) grammars, the run time is O(n).
	/// Best performance can be achieved with left recursive grammars.
	public init(grammar: Grammar) {
		self.grammar = grammar
	}
	
	public func syntaxTree(for tokenization: [[(terminal: Terminal, range: Range<String.Index>)]]) throws -> SyntaxTree<NonTerminal, Range<String.Index>> {
		
		var stateCollection: [Set<ParseState>] = []
		stateCollection.reserveCapacity(tokenization.count+1)
		
		let nonTerminalProductions = Dictionary(grouping: grammar.productions, by: {$0.pattern})
		
		stateCollection.append(nonTerminalProductions[grammar.start, default: []].map({ (production) -> ParseState in
			ParseState(production: production, productionPosition: 0, startTokenIndex: 0)
		}).collect(Set.init))
		
		func predict(state: Set<ParseState>, currentIndex: Int, known: Set<ParseState> = []) -> Set<ParseState> {
			let newItems: Set<ParseState> = state.reduce([]) { partialResult, item -> Set<ParseState> in
				// Prediction can only occur when a production has unparsed non terminal items left
				guard !item.isCompleted else {
					return partialResult
				}
				guard case .nonTerminal(let nonTerminal) = item.production.production[item.productionPosition] else {
					return partialResult
				}
				// Create new parse states for each non terminal which has been reached and filter out every known state
				let addedItems = nonTerminalProductions[nonTerminal, default: []].map {
					ParseState(production: $0, productionPosition: 0, startTokenIndex: currentIndex)
				}.filter{!state.contains($0) && !known.contains($0)}
				
				return partialResult.union(addedItems)
			}
			// If no new items have been found, prediction is done.
			if newItems.isEmpty {
				return known.union(state)
			} else {
				// If new items have been found, these items may lead to more items,
				// so prediction is performed again on the new items.
				
				// Tail recursive call
				return predict(state: newItems, currentIndex: currentIndex, known: known.union(state))
			}
		}
		
		func scan(state: Set<ParseState>, token: Terminal) -> Set<ParseState> {
			return state.reduce(into: []) { partialResult, item in
				// Bound checking
				guard !item.isCompleted else {
					return
				}
				// Check that the current symbol of the production is a terminal and if yes
				// check that it matches the current token
				guard
					case .terminal(let terminal) = item.production.production[item.productionPosition],
					terminal == token
				else {
					return
				}
				// Create a new state with an advanced production position.
				let newState = ParseState(
					production: item.production,
					productionPosition: item.productionPosition + 1,
					startTokenIndex: item.startTokenIndex
				)
				partialResult.insert(newState)
			}
		}
		
		func complete(state: Set<ParseState>, allStates: [Set<ParseState>], knownStates: Set<ParseState> = []) -> Set<ParseState> {
			let completedItems = state.filter(\.isCompleted)
			// Find the items which were used to enqueue the completed items
			let generatingItems = completedItems.flatMap { item in
				allStates[item.startTokenIndex].filter{ stateItem in
					stateItem.production.production[stateItem.productionPosition] == Symbol.nonTerminal(item.production.pattern)
				}
			}
			let completedStates = generatingItems.map{ item in
				ParseState(production: item.production, productionPosition: item.productionPosition + 1, startTokenIndex: item.startTokenIndex)
			}.collect(Set.init).subtracting(knownStates)
			
			if completedStates.isEmpty {
				return knownStates
			} else {
				return complete(state: completedStates, allStates: allStates, knownStates: knownStates.union(completedStates))
			}
		}
		
		stateCollection[0] = predict(state: stateCollection[0], currentIndex: 0)
		
		for (index, tokens) in tokenization.enumerated() {
			stateCollection.append(tokens.reduce([]) { partialResult, token -> Set<ParseState> in
				partialResult.union(scan(state: stateCollection[index], token: token.terminal))
			})
			stateCollection[index+1] = complete(state: stateCollection[index+1], allStates: stateCollection, knownStates: stateCollection[index+1])
			stateCollection[index+1] = predict(state: stateCollection[index+1], currentIndex: index+1)
		}
		
		if stateCollection.last!.contains(where: { (parseState) -> Bool in
			parseState.production.pattern == self.grammar.start
			&& parseState.isCompleted
		}) {
			print("Parsing successful.")
		} else {
			print("Parsing failed.")
		}
		
		fatalError()
	}
}
