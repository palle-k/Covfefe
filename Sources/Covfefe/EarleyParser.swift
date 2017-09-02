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
fileprivate struct ParseStateItem {
	/// The partially parsed production
	let production: Production
	
	/// The index of the next symbol to be parsed
	let productionPosition: Int
	
	/// The index of the first token parsed in this partial parse
	let startTokenIndex: Int
}

extension ParseStateItem {
	var isCompleted: Bool {
		return !production.production.indices.contains(productionPosition)
	}
}

extension ParseStateItem: Hashable {
	static func ==(lhs: ParseStateItem, rhs: ParseStateItem) -> Bool {
		return lhs.production == rhs.production
			&& lhs.productionPosition == rhs.productionPosition
			&& lhs.startTokenIndex == rhs.startTokenIndex
	}
	
	var hashValue: Int {
		return production.hashValue ^ productionPosition.hashValue ^ (startTokenIndex.hashValue << 32) ^ (startTokenIndex.hashValue >> 32)
	}
}

extension ParseStateItem: CustomStringConvertible {
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

/// A parse edge
fileprivate struct ParseEdge {
	/// The production
	let production: Production
	
	/// State index at which the item was completed
	let completedIndex: Int
}

extension ParseEdge: Hashable {
	var hashValue: Int {
		return production.hashValue ^ completedIndex.hashValue
	}
	
	static func ==(lhs: ParseEdge, rhs: ParseEdge) -> Bool {
		return lhs.production == rhs.production && lhs.completedIndex == rhs.completedIndex
	}
}

extension ParseEdge: CustomStringConvertible {
	var description: String {
		let producedString = production.production.reduce("") { (partialResult, symbol) -> String in
			switch symbol {
			case .nonTerminal(let nonTerminal):
				return partialResult.appending(" <\(nonTerminal.name)>")
				
			case .terminal(let terminal):
				return partialResult.appending(" '\(terminal.value)'")
			}
		}
		return "<\(production.pattern.name)> ::=\(producedString) \(completedIndex)"
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
	
	// Collects productions which can be reached indirectly.
	// e.g. for a production A -> BC which is not already partially parsed, all productions starting from B will be collected.
	private func predict(productions: [NonTerminal: [Production]], state: Set<ParseStateItem>, currentIndex: Int, known: Set<ParseStateItem> = []) -> Set<ParseStateItem> {
		let newItems: Set<ParseStateItem> = state.reduce([]) { partialResult, item -> Set<ParseStateItem> in
			// Prediction can only occur when a production has unparsed non terminal items left
			guard !item.isCompleted else {
				return partialResult
			}
			guard case .nonTerminal(let nonTerminal) = item.production.production[item.productionPosition] else {
				return partialResult
			}
			// Create new parse states for each non terminal which has been reached and filter out every known state
			let addedItems = productions[nonTerminal, default: []].map {
				ParseStateItem(production: $0, productionPosition: 0, startTokenIndex: currentIndex)
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
			return predict(productions: productions, state: newItems, currentIndex: currentIndex, known: known.union(state))
		}
	}
	
	// Finds productions which produce a non terminal and checks,
	// if the expected terminal matches the observed one.
	private func scan(state: Set<ParseStateItem>, token: Terminal) -> Set<ParseStateItem> {
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
			let newState = ParseStateItem(
				production: item.production,
				productionPosition: item.productionPosition + 1,
				startTokenIndex: item.startTokenIndex
			)
			partialResult.insert(newState)
		}
	}
	
	// Finds completed items
	private func complete(state: Set<ParseStateItem>, allStates: [Set<ParseStateItem>], knownItems: Set<ParseStateItem> = []) -> Set<ParseStateItem> {
		let completedItems = state.filter(\.isCompleted)
		// Find the items which were used to enqueue the completed items
		let generatingItems = completedItems.flatMap { item in
			allStates[item.startTokenIndex].filter{ stateItem in
				stateItem.production.production[stateItem.productionPosition] == Symbol.nonTerminal(item.production.pattern)
			}
		}
		// Create new state items for those items and remove every item that is already known
		let completedStates = generatingItems.map{ item in
			ParseStateItem(production: item.production, productionPosition: item.productionPosition + 1, startTokenIndex: item.startTokenIndex)
			}.collect(Set.init).subtracting(knownItems)
		
		// If no new states have been added, we are done
		if completedStates.isEmpty {
			return knownItems
		} else {
			// If we found new states, these may also be completed so we call the function again with the newly found items.
			// Tail recursive call
			return complete(state: completedStates, allStates: allStates, knownItems: knownItems.union(completedStates))
		}
	}
	
	private func buildSyntaxTree(
		stateCollection: [Set<ParseStateItem>],
		tokenization: [[(terminal: Terminal, range: Range<String.Index>)]],
		rootItem: ParseStateItem,
		endIndex: Int
	) -> SyntaxTree<NonTerminal, Range<String.Index>> {
		
		guard !rootItem.production.production.isEmpty else {
			return SyntaxTree(key: rootItem.production.pattern)
		}
		
		let childTrees = rootItem.production.production.enumerated().reversed().reduce((endIndex, [])) { (partialResult, element) -> (Int, [SyntaxTree<NonTerminal, Range<String.Index>>]) in
			let (upperBound, children) = partialResult
			let (offset, symbol) = element
			
			switch symbol {
			case .terminal:
				let leaf = SyntaxTree<NonTerminal, Range<String.Index>>(value: tokenization[upperBound-1].first!.range)
				return (upperBound - 1, children + [leaf])
				
			case .nonTerminal(let nonTerminal):
				let parseItem = stateCollection[endIndex].first(where: { candidate -> Bool in
					candidate.isCompleted
						&& candidate.production.pattern == nonTerminal
						&& stateCollection[candidate.startTokenIndex].contains(
							ParseStateItem(
								production: rootItem.production,
								productionPosition: offset,
								startTokenIndex: rootItem.startTokenIndex
							)
						)
				})!
				let childTree = buildSyntaxTree(stateCollection: stateCollection, tokenization: tokenization, rootItem: parseItem, endIndex: upperBound)
				return (parseItem.startTokenIndex, children + [childTree])
			}
		}.1.reversed().collect(Array.init)
		
		return SyntaxTree(key: rootItem.production.pattern, children: childTrees)
	}
	
	public func syntaxTree(for tokenization: [[(terminal: Terminal, range: Range<String.Index>)]]) throws -> SyntaxTree<NonTerminal, Range<String.Index>> {
		//TODO: Support empty productions
		//TODO: Better support for right recursion
		//TODO: Generate syntax tree
		
		var stateCollection: [Set<ParseStateItem>] = []
		stateCollection.reserveCapacity(tokenization.count+1)
		
		let nonTerminalProductions = Dictionary(grouping: grammar.productions, by: {$0.pattern})
		
		// The start state contains all productions which can be reached directly from the starting non terminal
		stateCollection.append(nonTerminalProductions[grammar.start, default: []].map({ (production) -> ParseStateItem in
			ParseStateItem(production: production, productionPosition: 0, startTokenIndex: 0)
		}).collect(Set.init))
		
		stateCollection[0] = predict(productions: nonTerminalProductions, state: stateCollection[0], currentIndex: 0)
		print("State \(0): [\n\t\(stateCollection[0].map(\.description).joined(separator: "\n\t"))\n]")
		
		// Parse loop: Scan token, find finished productions and update dependent productions and find new productions
		stateCollection = tokenization.enumerated().reduce(into: stateCollection) { (stateCollection, element) in
			let (index, tokens) = element
			let newItems = tokens.reduce([]) { partialResult, token -> Set<ParseStateItem> in
				partialResult.union(scan(state: stateCollection[index], token: token.terminal))
			}
			let completed = complete(state: newItems, allStates: stateCollection, knownItems: newItems)
			let predicted = predict(productions: nonTerminalProductions, state: completed, currentIndex: index + 1)
			stateCollection.append(predicted)
			
			print("State \(index+1): [\n\t\(predicted.map(\.description).joined(separator: "\n\t"))\n]")
		}
		
		guard let match = stateCollection.last!.first(where: { (parseState) -> Bool in
			parseState.startTokenIndex == 0
				&& parseState.isCompleted
				&& parseState.production.pattern == self.grammar.start
		}) else {
			throw SyntaxError(range: "".startIndex ..< "".endIndex, reason: .unmatchedPattern)
		}
		
		return buildSyntaxTree(stateCollection: stateCollection, tokenization: tokenization, rootItem: match, endIndex: stateCollection.count - 1)
	}
}
