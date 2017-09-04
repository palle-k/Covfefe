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
	
	func advanced() -> ParseStateItem {
		guard !isCompleted else {
			return self
		}
		return ParseStateItem(
			production: production,
			productionPosition: productionPosition + 1,
			startTokenIndex: startTokenIndex
		)
	}
	
	var nextSymbol: Symbol? {
		guard production.production.indices.contains(productionPosition) else {
			return nil
		}
		return production.production[productionPosition]
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
				return "\"\(terminal.value.replacingOccurrences(of: "\n", with: "\\n"))\""
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
fileprivate struct ParsedItem {
	/// The production
	let production: Production
	
	/// State index at which the item was completed
	let completedIndex: Int
}

extension ParsedItem: Hashable {
	var hashValue: Int {
		return production.hashValue ^ completedIndex.hashValue
	}
	
	static func ==(lhs: ParsedItem, rhs: ParsedItem) -> Bool {
		return lhs.production == rhs.production && lhs.completedIndex == rhs.completedIndex
	}
}

extension ParsedItem: CustomStringConvertible {
	var description: String {
		let producedString = production.production.reduce("") { (partialResult, symbol) -> String in
			switch symbol {
			case .nonTerminal(let nonTerminal):
				return partialResult.appending(" <\(nonTerminal.name)>")
				
			case .terminal(let terminal):
				return partialResult.appending(" '\(terminal.value.replacingOccurrences(of: "\n", with: "\\n"))'")
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
	
	/// The grammar recognized by the parser
	public let grammar: Grammar
	
	/// All non terminals which have productions which can produce an empty string
	private let nullableNonTerminals: Set<NonTerminal>
	
	/// Generates an earley parser for the given grammar.
	///
	/// Creates a syntax tree in O(n^3) worst case run time.
	/// For unambiguous grammars, the run time is O(n^2).
	/// For almost all LR(k) grammars, the run time is O(n).
	/// Best performance can be achieved with left recursive grammars.
	public init(grammar: Grammar) {
		self.grammar = grammar
		self.nullableNonTerminals = grammar.productions.flatMap { production in
			if production.generatesEmpty(in: grammar) {
				return production.pattern
			} else {
				return nil
			}
		}.collect(Set.init)
	}
	
	// Collects productions which can be reached indirectly.
	// e.g. for a production A -> BC which is not already partially parsed, all productions starting from B will be collected.
	private func predict(
		productions: [NonTerminal: [Production]],
		item: ParseStateItem,
		currentIndex: Int,
		knownItems: Set<ParseStateItem>
	) -> Set<ParseStateItem> {
		guard
			let symbol = item.nextSymbol,
			case .nonTerminal(let nonTerminal) = symbol
		else {
			return []
		}
		// Create new parse states for each non terminal which has been reached and filter out every known state
		let addedItems = productions[nonTerminal, default: []].map {
			ParseStateItem(production: $0, productionPosition: 0, startTokenIndex: currentIndex)
		}.collect(Set.init).subtracting(knownItems)
		
		// If a nullable symbol was added, advance the production that added this symbol
		if nullableNonTerminals.contains(nonTerminal) {
			return Set(addedItems + [item.advanced()])
		}
		
		return Set(addedItems)
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
			partialResult.insert(item.advanced())
		}
	}
	
	// Finds completed items
	private func complete(
		item: ParseStateItem,
		allStates: [Set<ParseStateItem>],
		knownItems: Set<ParseStateItem>
	) -> Set<ParseStateItem> {
		guard item.isCompleted else {
			return []
		}
		
		// Find the items which were used to enqueue the completed items
		let generatingItems = (allStates.indices.contains(item.startTokenIndex) ? allStates[item.startTokenIndex] : [])
			.union(knownItems).filter { stateItem in
				!stateItem.isCompleted
					&& stateItem.nextSymbol == Symbol.nonTerminal(item.production.pattern)
			}
		
		// Create new state items for those items and remove every item that is already known
		let completedItems = generatingItems.map { item in
			item.advanced()
		}.collect(Set.init).subtracting(knownItems)
		
		return completedItems
	}
	
	private func processState(
		productions: [NonTerminal: [Production]],
		allStates: [Set<ParseStateItem>],
		knownItems: Set<ParseStateItem>,
		newItems: Set<ParseStateItem>
	) -> Set<ParseStateItem> {
		let addedItems = newItems.reduce([]) { (addedItems, item) -> Set<ParseStateItem> in
			switch item.nextSymbol {
			case .none:
				return addedItems.union(complete(item: item, allStates: allStates, knownItems: knownItems))
				
			case .some(.terminal):
				return addedItems // Terminals are processed in scan before
				
			case .some(.nonTerminal):
				return addedItems.union(predict(productions: productions, item: item, currentIndex: allStates.count, knownItems: knownItems))
			}
		}.collect(Set.init).subtracting(knownItems)
		
		if addedItems.isEmpty {
			// No new items have been found so we are done.
			return knownItems
		} else {
			// Tail recursive call to process newly found items.
			return processState(
				productions: productions,
				allStates: allStates,
				knownItems: knownItems.union(addedItems),
				newItems: addedItems
			)
		}
	}
	
	private func buildSyntaxTree(
		stateCollection: [Set<ParsedItem>],
		tokenization: [[(terminal: Terminal, range: Range<String.Index>)]],
		rootItem: ParsedItem,
		startIndex: Int
	) -> SyntaxTree<NonTerminal, Range<String.Index>> {
		
		guard !rootItem.production.production.isEmpty else {
			return SyntaxTree(key: rootItem.production.pattern)
		}
		
		func resolveTokenization(
			unresolved: ArraySlice<Symbol>,
			position: Int
		) -> [SyntaxTree<NonTerminal, Range<String.Index>>]? {
			guard position <= rootItem.completedIndex else {
				return nil
			}
			
			guard let first = unresolved.first else {
				if position == rootItem.completedIndex {
					return []
				} else {
					return nil
				}
			}
			switch first {
			case .nonTerminal(let nonTerminal):
				let candidates = stateCollection[position].lazy.filter { candidate -> Bool in
					candidate.production.pattern == nonTerminal && (candidate != rootItem || startIndex != position)
				}
				return candidates.flatMap { candidate -> [SyntaxTree<NonTerminal, Range<String.Index>>]? in
					guard let resolved = resolveTokenization(
						unresolved: unresolved.dropFirst(),
						position: candidate.completedIndex
					) else {
						return nil
					}
					let node = self.buildSyntaxTree(
						stateCollection: stateCollection,
						tokenization: tokenization,
						rootItem: candidate,
						startIndex: position
					)
					return resolved + [node]
				}.first
				
			case .terminal(let terminal):
				guard position < tokenization.count else {
					return nil
				}
				guard let range = tokenization[position].first(where: { element -> Bool in
					element.terminal == terminal
				})?.range else {
					return nil
				}
				guard let rest = resolveTokenization(unresolved: unresolved.dropFirst(), position: position + 1) else {
					return nil
				}
				return rest + [.leaf(range)]
			}
		}
		
		let children:[SyntaxTree<NonTerminal, Range<String.Index>>] = resolveTokenization(unresolved: ArraySlice(rootItem.production.production), position: startIndex)!.reversed()
		return SyntaxTree.node(key: rootItem.production.pattern, children: children)
	}
	
	public func syntaxTree(for tokenization: [[(terminal: Terminal, range: Range<String.Index>)]]) throws -> SyntaxTree<NonTerminal, Range<String.Index>> {
		//TODO: Better support for right recursion
		
		var stateCollection: [Set<ParseStateItem>] = []
		stateCollection.reserveCapacity(tokenization.count+1)
		
		let nonTerminalProductions = Dictionary(grouping: grammar.productions, by: {$0.pattern})
		
		// The start state contains all productions which can be reached directly from the starting non terminal
		stateCollection.append(nonTerminalProductions[grammar.start, default: []].map({ (production) -> ParseStateItem in
			ParseStateItem(production: production, productionPosition: 0, startTokenIndex: 0)
		}).collect(Set.init))
		
		stateCollection[0] = processState(
			productions: nonTerminalProductions,
			allStates: [],
			knownItems: stateCollection[0],
			newItems: stateCollection[0]
		)
//		print("State \(0): [\n\t\(stateCollection[0].map(\.description).sorted().joined(separator: "\n\t"))\n]")
		
		// Parse loop: Scan token, find finished productions and update dependent productions and find new productions
		stateCollection = try tokenization.reduce(into: stateCollection) { (stateCollection, tokens) in
			let newItems = tokens.reduce([]) { partialResult, token -> Set<ParseStateItem> in
				partialResult.union(scan(state: stateCollection.last!, token: token.terminal))
			}
			guard !newItems.isEmpty else {
				throw SyntaxError(range: tokens.first!.range, reason: .unexpectedToken)
			}
			let processed = processState(
				productions: nonTerminalProductions,
				allStates: stateCollection,
				knownItems: newItems,
				newItems: newItems
			)
			stateCollection.append(processed)
			
//			print("State \(stateCollection.indices.last!): [\n\t\(processed.map(\.description).sorted().joined(separator: "\n\t"))\n]")
		}
		
		let parseStates = stateCollection.enumerated().reduce(Array<Set<ParsedItem>>(repeating: [], count: stateCollection.count)) { (parseStates, element) in
			let (index, state) = element
			let completed = state.filter(\.isCompleted)
			return completed.reduce(into: parseStates) { (parseStates, item) in
				parseStates[item.startTokenIndex].insert(ParsedItem(production: item.production, completedIndex: index))
			}
		}
		
		guard let match = parseStates.first!.first(where: { (item) -> Bool in
			item.completedIndex == parseStates.count - 1 &&
			item.production.pattern == grammar.start
		}) else {
			let startItems = parseStates[0].filter { item in
				item.production.pattern == grammar.start
			}
			if let longestMatch = startItems.max(by: {$0.completedIndex < $1.completedIndex}) {
				let range = tokenization[longestMatch.completedIndex].first!.range
				throw SyntaxError(range: range, reason: .unmatchedPattern)
			} else {
				throw SyntaxError(range: tokenization.first?.first?.range ?? ("".startIndex ..< "".endIndex), reason: .unmatchedPattern)
			}
		}
		
//		print(parseStates.enumerated().map {print("State \($0.offset): [\n\t\($0.element.map(\.description).joined(separator: "\n\t"))\n]")})
		
		return buildSyntaxTree(stateCollection: parseStates, tokenization: tokenization, rootItem: match, startIndex: 0)
	}
}
