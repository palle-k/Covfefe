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

public typealias ParseTree = SyntaxTree<NonTerminal, Range<String.Index>>

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
		return "<\(production.pattern.name)> ::=\(producedString) (\(completedIndex))"
	}
}


/// A parser generator implementation that internally uses
/// the Earley algorithm.
///
/// Creates a syntax tree in O(n^3) worst case run time.
/// For unambiguous grammars, the run time is O(n^2).
/// For almost all LR(k) grammars, the run time is O(n).
/// Best performance can be achieved with left recursive grammars.
///
/// For ambiguous grammars, the runtime for parses may increase,
/// as some expressions have exponentially many possible parse trees depending on expression length.
/// This exponential growth can be avoided by only generating a single parse tree with `syntaxTree(for:)`.
///
/// For unambiguous grammars, the Earley parser performs better than the CYK parser.
public struct EarleyParser: AmbiguousGrammarParser {
	
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
	) -> [ParseStateItem] {
		guard
			let symbol = item.nextSymbol,
			case .nonTerminal(let nonTerminal) = symbol
		else {
			return []
		}
		// Create new parse states for each non terminal which has been reached and filter out every known state
		let addedItems = productions[nonTerminal, default: []].map {
			ParseStateItem(production: $0, productionPosition: 0, startTokenIndex: currentIndex)
		}
		
		// If a nullable symbol was added, advance the production that added this symbol
		if nullableNonTerminals.contains(nonTerminal) {
			return addedItems + [item.advanced()]
		}
		
		return addedItems
	}
	
	// Finds productions which produce a non terminal and checks,
	// if the expected terminal matches the observed one.
	private func scan(state: Set<ParseStateItem>, token: Terminal) -> Set<ParseStateItem> {
		return state.reduce(into: []) { partialResult, item in
			// Check that the current symbol of the production is a terminal and if yes
			// check that it matches the current token
			guard
				let next = item.nextSymbol,
				case .terminal(let terminal) = next,
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
	) -> [ParseStateItem] {
		guard item.isCompleted else {
			return []
		}
		
		// Find the items which were used to enqueue the completed items
		let generatingItems = (allStates.indices.contains(item.startTokenIndex) ? allStates[item.startTokenIndex] : [])
			.filter { stateItem in
				!stateItem.isCompleted
					&& stateItem.nextSymbol == Symbol.nonTerminal(item.production.pattern)
			}
		
		return generatingItems.map { item in
			item.advanced()
		}
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
		}.subtracting(knownItems)
		
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
	
	private func buildSyntaxTrees(
		stateCollection: [Set<ParsedItem>],
		tokenization: [[(terminal: Terminal, range: Range<String.Index>)]],
		rootItem: ParsedItem,
		startIndex: Int,
		ignoreAmbiguousItems: Bool
	) -> [ParseTree] {
		
		guard !rootItem.production.production.isEmpty else {
			return [SyntaxTree(key: rootItem.production.pattern)]
		}
		
		func resolve(
			unresolved: ArraySlice<Symbol>,
			position: Int
		) -> [[(Int, Either<ParsedItem, Terminal>)]] {
			guard position <= rootItem.completedIndex else {
				return []
			}
			
			guard let first = unresolved.first else {
				if position == rootItem.completedIndex {
					return [[]]
				} else {
					return []
				}
			}
			switch first {
			case .nonTerminal(let nonTerminal):
				let candidates = stateCollection[position].lazy.filter { candidate -> Bool in
					candidate.production.pattern == nonTerminal
						&& (candidate != rootItem || startIndex != position)
						&& candidate.completedIndex <= rootItem.completedIndex
				}
				let resolvedCandidates = candidates.lazy.flatMap { candidate -> [[(Int, Either<ParsedItem, Terminal>)]] in
					let resolved = resolve(
						unresolved: unresolved.dropFirst(),
						position: candidate.completedIndex
					)
					return resolved.map{$0 + [(position, .first(candidate))]}
				}
				if ignoreAmbiguousItems {
					guard let first = resolvedCandidates.first else {
						return []
					}
					return [first]
				} else {
					return resolvedCandidates.collect(Array.init)
				}
				
			case .terminal(let terminal):
				// A terminal can only be scanned if there is at least one token left.
				guard position < tokenization.count else {
					return []
				}
				// The position might be wrong, so we check that the terminal actually occurred at the current position
				guard tokenization[position].contains(where: {$0.terminal == terminal}) else {
					return []
				}
				// Try to resolve the rest.
				let rest = resolve(unresolved: unresolved.dropFirst(), position: position + 1)
				return rest.map{$0 + [(position, .second(terminal))]}
			}
		}
		
		// Faster return for unambiguous grammars
		if ignoreAmbiguousItems {
			let first = resolve(unresolved: ArraySlice(rootItem.production.production), position: startIndex)[0].reversed()
			let children = first.map { (element) -> ParseTree in
				let (position, root) = element
				return root.combine({ parsedItem -> ParseTree in
					self.buildSyntaxTrees(
						stateCollection: stateCollection,
						tokenization: tokenization,
						rootItem: parsedItem,
						startIndex: position,
						ignoreAmbiguousItems: ignoreAmbiguousItems
					).first!
				}, { _ -> ParseTree in
					return .leaf(tokenization[position].first!.range)
				})
			}
			return [ParseTree.node(key: rootItem.production.pattern, children: children)]
		}
		
		let parseTrees = resolve(
			unresolved: ArraySlice(rootItem.production.production),
			position: startIndex
		).map { children -> [(Int, Either<ParsedItem, Terminal>)] in
			children.reversed()
		}.lazy.flatMap { children -> [[ParseTree]] in
			children.map { element -> [ParseTree] in
				let (position, root) = element
				return root.combine({ parsedItem -> [ParseTree] in
					self.buildSyntaxTrees(
						stateCollection: stateCollection,
						tokenization: tokenization,
						rootItem: parsedItem,
						startIndex: position,
						ignoreAmbiguousItems: ignoreAmbiguousItems
					)
				}, { _ -> [ParseTree] in
					return [.leaf(tokenization[position].first!.range)]
				})
			}.combinations()
		}.map { (children) -> ParseTree in
			ParseTree.node(key: rootItem.production.pattern, children: children)
		}
		
		if parseTrees.isEmpty {
			fatalError("Internal error: Could not build syntax tree after successful parse.")
		}
		
		if ignoreAmbiguousItems {
			return [parseTrees.first!]
		}
		
		return parseTrees.collect(Array.init)
	}
	
	private func parse(_ string: String) throws -> ([Set<ParsedItem>], [[(terminal: Terminal, range: Range<String.Index>)]]) {
		//TODO: Better support for right recursion
		
		let nonTerminalProductions = Dictionary(grouping: grammar.productions, by: {$0.pattern})
		
		// The start state contains all productions which can be reached directly from the starting non terminal
		let initState = nonTerminalProductions[grammar.start, default: []].map({ (production) -> ParseStateItem in
			ParseStateItem(production: production, productionPosition: 0, startTokenIndex: 0)
		}).collect(Set.init).collect { initState in
			processState(productions: nonTerminalProductions, allStates: [], knownItems: initState, newItems: initState)
		}
		
		var tokenization: [[(terminal: Terminal, range: Range<String.Index>)]] = []
		tokenization.reserveCapacity(string.count)
		
		var stateCollection: [Set<ParseStateItem>] = [initState]
		stateCollection.reserveCapacity(string.count + 1)
		
		var currentIndex = string.startIndex
		
		while currentIndex < string.endIndex {
			let lastState = stateCollection.last!
			
			let expectedTerminals = Dictionary(
				grouping: lastState.flatMap { item -> (item: ParseStateItem, terminal: Terminal)? in
					guard case .some(.terminal(let terminal)) = item.nextSymbol else {
						return nil
					}
					return (item: item, terminal: terminal)
				},
				by: { pair in
					pair.terminal
			}
				).mapValues { pairs in
					pairs.map { pair in
						pair.item
					}
			}
			
			let (newItems, tokens): ([[ParseStateItem]], [(terminal: Terminal, range: Range<String.Index>)]) =
				expectedTerminals.flatMap { (terminal, items) -> (items: [ParseStateItem], token: (terminal: Terminal, range: Range<String.Index>))? in
					guard let range = string.rangeOfPrefix([terminal], from: currentIndex), range.lowerBound == currentIndex else {
						return nil
					}
					return (items.map{$0.advanced()}, (terminal, range))
					}.collect(unzip)
			
			guard !newItems.isEmpty else {
				let context = lastState.flatMap { item -> NonTerminal? in
					switch item.nextSymbol {
					case .none:
						return nil
					case .some(.terminal):
						return nil
					case .some(.nonTerminal(let nonTerminal)):
						return nonTerminal
					}
				}.filter { nonTerminal -> Bool in
					nonTerminalProductions[nonTerminal, default: []].contains(where: { production -> Bool in
						if case .some(.terminal) = production.production.first {
							return true
						} else {
							return false
						}
					})
				}
				throw SyntaxError(
					range: currentIndex ..< string.index(after: currentIndex),
					in: string,
					reason: context.isEmpty ? .unexpectedToken : .unmatchedPattern,
					context: context
				)
			}
			
			let newItemSet = newItems.flatMap{$0}.collect(Set.init)
			
			tokenization.append(tokens)
			stateCollection.append(
				processState(
					productions: nonTerminalProductions,
					allStates: stateCollection,
					knownItems: newItemSet,
					newItems: newItemSet
				)
			)
			
			currentIndex = tokens.first!.range.upperBound
		}
		
		let parseStates = stateCollection.enumerated().reduce(Array<Set<ParsedItem>>(repeating: [], count: stateCollection.count)) { (parseStates, element) in
			let (index, state) = element
			let completed = state.filter(\.isCompleted)
			return completed.reduce(into: parseStates) { (parseStates, item) in
				parseStates[item.startTokenIndex].insert(ParsedItem(production: item.production, completedIndex: index))
			}
		}
		
		return (parseStates, tokenization)
	}
	
	public func syntaxTree(for string: String) throws -> ParseTree {
		let (parseStates, tokenization) = try parse(string)
		
		guard let match = parseStates.first!.first(where: { item -> Bool in
			item.completedIndex == parseStates.count - 1 &&
				item.production.pattern == grammar.start
		}) else {
			let startItems = parseStates[0].filter { item in
				item.production.pattern == grammar.start
			}
			if let longestMatch = startItems.max(by: {$0.completedIndex < $1.completedIndex}) {
				let range = tokenization[longestMatch.completedIndex].first!.range
				throw SyntaxError(range: range, in: string, reason: .unmatchedPattern)
			} else {
				throw SyntaxError(range: tokenization.first?.first?.range ?? (string.startIndex ..< string.endIndex), in: string, reason: .unmatchedPattern)
			}
		}
		
		return buildSyntaxTrees(stateCollection: parseStates, tokenization: tokenization, rootItem: match, startIndex: 0, ignoreAmbiguousItems: true)[0]
	}
	
	public func allSyntaxTrees(for string: String) throws -> [ParseTree] {
		let (parseStates, tokenization) = try parse(string)
		let matches = parseStates.first!.filter { item -> Bool in
			item.completedIndex == parseStates.count - 1 &&
				item.production.pattern == grammar.start
		}
		guard !matches.isEmpty else {
			let startItems = parseStates[0].filter { item in
				item.production.pattern == grammar.start
			}
			if let longestMatch = startItems.max(by: {$0.completedIndex < $1.completedIndex}) {
				let range = tokenization[longestMatch.completedIndex].first!.range
				throw SyntaxError(range: range, in: string, reason: .unmatchedPattern)
			} else {
				throw SyntaxError(range: tokenization.first?.first?.range ?? (string.startIndex ..< string.endIndex), in: string, reason: .unmatchedPattern)
			}
		}
		return matches.flatMap { match in
			buildSyntaxTrees(stateCollection: parseStates, tokenization: tokenization, rootItem: match, startIndex: 0, ignoreAmbiguousItems: false)
		}
	}
}
