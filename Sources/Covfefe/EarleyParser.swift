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
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(hashValue)
    }
}

extension ParseStateItem: CustomStringConvertible {
	var description: String {
		let producedString = production.production.map { symbol -> String in
			switch symbol {
			case .nonTerminal(let nonTerminal):
				return "<\(nonTerminal.name)>"
				
			case .terminal(let terminal):
				return "\"\(terminal.description.replacingOccurrences(of: "\n", with: "\\n"))\""
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
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(hashValue)
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
				return partialResult.appending(" '\(terminal.description.replacingOccurrences(of: "\n", with: "\\n"))'")
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
		self.nullableNonTerminals = grammar.productions.compactMap { production in
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
		var addedItems: Set<ParseStateItem> = newItems
		var knownItems: Set<ParseStateItem> = knownItems
		
		repeat {
			addedItems = addedItems.reduce(into: Set<ParseStateItem>()) { (addedItems, item) in
				switch item.nextSymbol {
				case .none:
					let completed = complete(item: item, allStates: allStates, knownItems: knownItems)
					addedItems.reserveCapacity(addedItems.count + completed.count)
					addedItems.formUnion(completed)

				case .some(.terminal):
					break // Terminals are processed in scan before

				case .some(.nonTerminal):
					let predicted = predict(productions: productions, item: item, currentIndex: allStates.count, knownItems: knownItems)
					addedItems.reserveCapacity(addedItems.count + predicted.count)
					addedItems.formUnion(predicted)
				}
			}.subtracting(knownItems)

			knownItems.reserveCapacity(addedItems.count + knownItems.count)
			knownItems.formUnion(addedItems)

		} while !addedItems.isEmpty

		return knownItems
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
		
		// Faster return for unambiguous grammars
		if ignoreAmbiguousItems {
			let first = StateProcessor(
				stateCollection: stateCollection, 
				tokenization: tokenization, 
				rootItem: rootItem, 
				startIndex: startIndex, 
				ignoreAmbiguousItems: ignoreAmbiguousItems
			).resolve(unresolved: ArraySlice(rootItem.production.production), position: startIndex)[0].reversed()
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
		
		let parseTrees = StateProcessor(
			stateCollection: stateCollection, 
			tokenization: tokenization, 
			rootItem: rootItem, 
			startIndex: startIndex, 
			ignoreAmbiguousItems: ignoreAmbiguousItems
		).resolve(
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
		
		// Tokenize string while parsing it
		while currentIndex < string.endIndex {
			let lastState = stateCollection.last!
			
			// Collect all terminals which could occur at the current location according to the grammar
			let expectedTerminals = Dictionary(
				grouping: lastState.compactMap { item -> (item: ParseStateItem, terminal: Terminal)? in
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
			
			// Find the tokens which match the string
			let (newItems, tokens): ([[ParseStateItem]], [(terminal: Terminal, range: Range<String.Index>)]) =
				expectedTerminals.compactMap { (terminal, items) -> ([ParseStateItem], (terminal: Terminal, range: Range<String.Index>))? in
					guard let range = string.rangeOfPrefix(terminal, from: currentIndex), range.lowerBound == currentIndex else {
						return nil
					}
					return (items.map{$0.advanced()}, (terminal, range))
				}.collect(unzip)
			
			// Check if tokens have been found. Report a syntax error if none have been found
			guard !newItems.isEmpty else {
				// Find non terminals which are expected at the current location
				let context = lastState.compactMap { item -> NonTerminal? in
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
		
		// Find all successfully parsed Earley items
		let parseStates = stateCollection.enumerated().reduce(Array<Set<ParsedItem>>(repeating: [], count: stateCollection.count)) { (parseStates, element) in
			let (index, state) = element
			let completed = state.filter {$0.isCompleted}
			return completed.reduce(into: parseStates) { (parseStates, item) in
				parseStates[item.startTokenIndex].insert(ParsedItem(production: item.production, completedIndex: index))
			}
		}
		
		return (parseStates, tokenization)
	}
	
	/// Creates a syntax tree which explains how a word was derived from a grammar
	///
	/// - Parameter string: Input word, for which a parse tree should be generated
	/// - Returns: A syntax tree explaining how the grammar can be used to derive the word described by the given tokenization
	/// - Throws: A syntax error if the word is not in the language recognized by the parser
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
		
		return buildSyntaxTrees(stateCollection: parseStates, tokenization: tokenization, rootItem: match, startIndex: 0, ignoreAmbiguousItems: true)[0].explode(grammar.utilityNonTerminals.contains)[0]
	}
	
	/// Generates all syntax trees explaining how a word can be derived from a grammar.
	///
	/// This function should only be used for ambiguous grammars and if it is necessary to
	/// retrieve all parse trees, as it comes with an additional cost in runtime.
	///
	/// For unambiguous grammars, this function should return the same results as `syntaxTree(for:)`.
	///
	/// - Parameter string: Input word, for which all parse trees should be generated
	/// - Returns: All syntax trees which explain how the input was derived from the recognized grammar
	/// - Throws: A syntax error if the word is not in the language recognized by the parser
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
			buildSyntaxTrees(stateCollection: parseStates, tokenization: tokenization, rootItem: match, startIndex: 0, ignoreAmbiguousItems: false).map {
				$0.explode(grammar.utilityNonTerminals.contains)[0]
			}
		}
	}
}

private final class StateProcessor {
	let stateCollection: [Set<ParsedItem>]
	let tokenization: [[(terminal: Terminal, range: Range<String.Index>)]]
	let rootItem: ParsedItem
	let startIndex: Int
	let ignoreAmbiguousItems: Bool

	init(
		stateCollection: [Set<ParsedItem>],
		tokenization: [[(terminal: Terminal, range: Range<String.Index>)]],
		rootItem: ParsedItem,
		startIndex: Int,
		ignoreAmbiguousItems: Bool
	) {
		self.stateCollection = stateCollection
		self.tokenization = tokenization
		self.rootItem = rootItem
		self.startIndex = startIndex
		self.ignoreAmbiguousItems = ignoreAmbiguousItems
	}

	private var stack = [StateProcessorStackFrame]()

	private enum StateProcessorStackFrame {
		typealias Result = [[(Int, Either<ParsedItem, Terminal>)]]
		case nonTerminal(unresolved: ArraySlice<Symbol>, position: Int, result: Result?)
	} 


	func resolve(unresolved: ArraySlice<Symbol>, position: Int) -> [[(Int, Either<ParsedItem, Terminal>)]] {
		if ignoreAmbiguousItems {
			return resolveIgnoreAmbiguous(unresolved: unresolved, position: position)
		} else {
			return resolveUseAmbiguous(unresolved: unresolved, position: position)
		}
	}

	private func resolveUseAmbiguous(unresolved: ArraySlice<Symbol>, position: Int) -> [[(Int, Either<ParsedItem, Terminal>)]] {
		guard position <= rootItem.completedIndex else {
			return []
		}
		switch unresolved.first {
		case nil:
			return position == rootItem.completedIndex ? [[]] : []
		case .nonTerminal(let nonTerminal)?:

			// FRAME STORE!
			var result = [[(Int, Either<ParsedItem, Terminal>)]]()

			for index in 0..<stateCollection[position].count {
				
				// FRAME STORE!
				let candidate = stateCollection[position][stateCollection[position].index(stateCollection[position].startIndex, offsetBy: index)]
				
				
				guard candidate.production.pattern == nonTerminal
					&& (candidate != self.rootItem || self.startIndex != position)
					&& candidate.completedIndex <= self.rootItem.completedIndex 
				else {
					continue
				}
				let resolved = self.resolveIgnoreAmbiguous(
					unresolved: unresolved.dropFirst(),
					position: candidate.completedIndex
				)
				let item = resolved.map{$0 + [(position, .first(candidate))]}

				result.append(contentsOf: item)
			}

			return result
		case .terminal(let terminal)?:
			// A terminal can only be scanned if there is at least one token left.
			guard position < tokenization.count else {
				return []
			}
			// The position might be wrong, so we check that the terminal actually occurred at the current position
			guard tokenization[position].contains(where: {$0.terminal == terminal}) else {
				return []
			}
			// Try to resolve the rest.
			let rest = resolveUseAmbiguous(unresolved: unresolved.dropFirst(), position: position + 1)
			return rest.map{$0 + [(position, .second(terminal))]}
		}
	}

	private func resolveIgnoreAmbiguous(unresolved: ArraySlice<Symbol>, position: Int) -> [[(Int, Either<ParsedItem, Terminal>)]] {
		guard position <= rootItem.completedIndex else {
			return []
		}
		switch unresolved.first {
		case nil:
			return position == rootItem.completedIndex ? [[]] : []
		case .nonTerminal(let nonTerminal)?:
			for index in 0..<stateCollection[position].count {
				
				// FRAME STORE!
				let candidate = stateCollection[position][stateCollection[position].index(stateCollection[position].startIndex, offsetBy: index)]
				
				
				guard candidate.production.pattern == nonTerminal
					&& (candidate != self.rootItem || self.startIndex != position)
					&& candidate.completedIndex <= self.rootItem.completedIndex 
				else {
					continue
				}
				let resolved = self.resolveIgnoreAmbiguous(
					unresolved: unresolved.dropFirst(),
					position: candidate.completedIndex
				)
				let item = resolved.map{$0 + [(position, .first(candidate))]}

				if !item.isEmpty {
					return item
				}
			}

			return []
		case .terminal(let terminal)?:
			// A terminal can only be scanned if there is at least one token left.
			guard position < tokenization.count else {
				return []
			}
			// The position might be wrong, so we check that the terminal actually occurred at the current position
			guard tokenization[position].contains(where: {$0.terminal == terminal}) else {
				return []
			}
			// Try to resolve the rest.
			let rest = resolveIgnoreAmbiguous(unresolved: unresolved.dropFirst(), position: position + 1)
			return rest.map{$0 + [(position, .second(terminal))]}
		}
	}
}