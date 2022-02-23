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
		
		return SyntaxTreeNonAmbiguousBuildingMachine(stateCollection: parseStates, tokenization: tokenization).buildSyntaxTrees(rootItem: match, startIndex: 0)[0].explode(grammar.utilityNonTerminals.contains)[0]
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
			SyntaxTreeAmbiguousBuildingMachine(stateCollection: parseStates, tokenization: tokenization).buildSyntaxTrees(rootItem: match, startIndex: 0).map {
				$0.explode(grammar.utilityNonTerminals.contains)[0]
			}
		}
	}
}

private final class SyntaxTreeAmbiguousBuildingMachine {
	typealias Result = [ParseTree]
	
	private enum StackFrame {
		case result(Result)
		case outerAmbiguousItemsBuildSyntaxTrees(rootItem: ParsedItem, parsed: [[(Int, Either<ParsedItem, Terminal>)]], accumulator: [[ParseTree]], iteratedIndex: Int)
		case outerResult([[ParseTree]])
		case innerAmbiguousItemsBuildSyntaxTrees(parsed: [(Int, Either<ParsedItem, Terminal>)], accumulator: [[ParseTree]], iteratedIndex: Int)

	} 

	private let stateCollection: [[ParsedItem]]
	private let tokenization: [[(terminal: Terminal, range: Range<String.Index>)]]

	private var stack = [StackFrame]()

	init(stateCollection: [Set<ParsedItem>], tokenization: [[(terminal: Terminal, range: Range<String.Index>)]]) {
		self.stateCollection = stateCollection.map(Array.init(_:))
		self.tokenization = tokenization
	}

	func buildSyntaxTrees(rootItem: ParsedItem, startIndex: Int) -> Result {
		appendNewAmbiguous(rootItem: rootItem, startIndex: startIndex)
		return runMachine()
	}

	private func runMachine() -> Result {
		var lastResult: Result?
		var lastOuterResult: [[ParseTree]]?

		while let currentItem = stack.popLast() {
			switch currentItem {
			case let .result(result):
				lastResult = result
				lastOuterResult = nil
			case let .outerAmbiguousItemsBuildSyntaxTrees(rootItem: rootItem, parsed: parsed, accumulator: accumulator, iteratedIndex: iteratedIndex):
				resolveOuterAmbiguousItemsBuildSyntaxTrees(rootItem: rootItem, parsed: parsed, accumulator: accumulator, iteratedIndex: iteratedIndex, outerResult: lastOuterResult)
				lastResult = nil
				lastOuterResult = nil
			case let .outerResult(outerResult):
				lastResult = nil
				lastOuterResult = outerResult
			case let .innerAmbiguousItemsBuildSyntaxTrees(parsed: parsed, accumulator: accumulator, iteratedIndex: iteratedIndex):
				resolveInnerAmbiguousItemsBuildSyntaxTrees(parsed: parsed, accumulator: accumulator, iteratedIndex: iteratedIndex, result: lastResult)
				lastResult = nil
				lastOuterResult = nil
			}
		}

		return lastResult!
	}

	private func appendNewAmbiguous(rootItem: ParsedItem, startIndex: Int) {
		guard !rootItem.production.production.isEmpty else {
			stack.append(.result([SyntaxTree(key: rootItem.production.pattern)]))
			return
		}

		let parsed = GrammarResolvingMachine(
			stateCollection: stateCollection, 
			tokenization: tokenization, 
			rootItem: rootItem, 
			startIndex: startIndex, 
			ignoreAmbiguousItems: false
		).resolve(
			unresolved: ArraySlice(rootItem.production.production),
			position: startIndex
		).map { children -> [(Int, Either<ParsedItem, Terminal>)] in
			children.reversed()
		}

		stack.append(.outerAmbiguousItemsBuildSyntaxTrees(rootItem: rootItem, parsed: parsed, accumulator: [[ParseTree]](), iteratedIndex: 0))	
	}

	private func resolveOuterAmbiguousItemsBuildSyntaxTrees(rootItem: ParsedItem, parsed: [[(Int, Either<ParsedItem, Terminal>)]], accumulator: [[ParseTree]], iteratedIndex: Int, outerResult: [[ParseTree]]?) {
		let newAccumulator = accumulator + (outerResult?.combinations() ?? [])

		guard parsed.count > iteratedIndex else {
			let result = newAccumulator.map { (children) -> ParseTree in
				ParseTree.node(key: rootItem.production.pattern, children: children)
			}
			if result.isEmpty {
				fatalError("Internal error: Could not build syntax tree after successful parse.")
			}

			stack.append(.result(result))
			return
		} 


		let anItem = parsed[iteratedIndex]

		stack.append(.outerAmbiguousItemsBuildSyntaxTrees(rootItem: rootItem, parsed: parsed, accumulator: newAccumulator, iteratedIndex: iteratedIndex + 1))
		stack.append(.innerAmbiguousItemsBuildSyntaxTrees(parsed: anItem, accumulator: [[ParseTree]](), iteratedIndex: 0))
	}

	private func resolveInnerAmbiguousItemsBuildSyntaxTrees(parsed: [(Int, Either<ParsedItem, Terminal>)],	accumulator: [[ParseTree]], iteratedIndex: Int, result: [ParseTree]?) {
		var newAccumulator = accumulator
		if let result = result {
			newAccumulator.append(result)
		}

		guard parsed.count > iteratedIndex else {
			stack.append(.outerResult(newAccumulator))
			return
		}

		let (position, root) = parsed[iteratedIndex]

		switch root {
		case let .first(parsedItem):
			stack.append(.innerAmbiguousItemsBuildSyntaxTrees(parsed: parsed, accumulator: newAccumulator, iteratedIndex: iteratedIndex + 1))
			appendNewAmbiguous(rootItem: parsedItem, startIndex: position)
		case .second:
			stack.append(.innerAmbiguousItemsBuildSyntaxTrees(parsed: parsed, accumulator: newAccumulator, iteratedIndex: iteratedIndex + 1))
			stack.append(.result([.leaf(self.tokenization[position].first!.range)]))
		}
	}

}

private final class SyntaxTreeNonAmbiguousBuildingMachine {
	typealias Result = [ParseTree]
	
	private enum StackFrame {
		case result(Result)
		case innerNonAmbiguousItemsBuildSyntaxTrees(rootItem: ParsedItem, parsed: [(Int, Either<ParsedItem, Terminal>)], accumulator: [ParseTree], iteratedIndex: Int)
	} 

	private let stateCollection: [[ParsedItem]]
	private let tokenization: [[(terminal: Terminal, range: Range<String.Index>)]]

	private var stack = [StackFrame]()

	init(stateCollection: [Set<ParsedItem>], tokenization: [[(terminal: Terminal, range: Range<String.Index>)]]) {
		self.stateCollection = stateCollection.map(Array.init(_:))
		self.tokenization = tokenization
	}

	func buildSyntaxTrees(rootItem: ParsedItem, startIndex: Int) -> Result {
		appendNewNonAmbiguous(rootItem: rootItem, startIndex: startIndex)
		return runMachine()
	}

	private func runMachine() -> Result {
		var lastResult: Result?

		while let currentItem = stack.popLast() {
			switch currentItem {
			case let .result(result):
				lastResult = result
			case let .innerNonAmbiguousItemsBuildSyntaxTrees(rootItem: rootItem, parsed: parsed, accumulator: accumulator, iteratedIndex: iteratedIndex):
				resolveInnerNonAmbiguousItemsBuildSyntaxTrees(rootItem: rootItem, parsed: parsed, accumulator: accumulator, iteratedIndex: iteratedIndex, result: lastResult)
				lastResult = nil
			}
		}

		return lastResult!
	}

	private func appendNewNonAmbiguous(rootItem: ParsedItem, startIndex: Int) {
		guard !rootItem.production.production.isEmpty else {
			stack.append(.result([SyntaxTree(key: rootItem.production.pattern)]))
			return
		}

		var first = GrammarResolvingMachine(
			stateCollection: stateCollection, 
			tokenization: tokenization, 
			rootItem: rootItem, 
			startIndex: startIndex, 
			ignoreAmbiguousItems: true
		).resolve(unresolved: ArraySlice(rootItem.production.production), position: startIndex)[0]
		
		first.reverse()

		stack.append(.innerNonAmbiguousItemsBuildSyntaxTrees(rootItem: rootItem, parsed: first, accumulator: [ParseTree](), iteratedIndex: 0))
	}

	private func resolveInnerNonAmbiguousItemsBuildSyntaxTrees(rootItem: ParsedItem, parsed: [(Int, Either<ParsedItem, Terminal>)],	 accumulator: [ParseTree], iteratedIndex: Int, result: [ParseTree]?) {
		var newAccumulator = accumulator
		if let result = result {
			newAccumulator.append(result.first!)
		}

		guard parsed.count > iteratedIndex else {
			stack.append(.result([ParseTree.node(key: rootItem.production.pattern, children: newAccumulator)]))
			return
		}

		let (position, root) = parsed[iteratedIndex]

		switch root {
		case let .first(parsedItem):
			stack.append(.innerNonAmbiguousItemsBuildSyntaxTrees(rootItem: rootItem, parsed: parsed, accumulator: newAccumulator, iteratedIndex: iteratedIndex + 1))
			appendNewNonAmbiguous(rootItem: parsedItem, startIndex: position)
		case .second:
			stack.append(.innerNonAmbiguousItemsBuildSyntaxTrees(rootItem: rootItem, parsed: parsed, accumulator: newAccumulator, iteratedIndex: iteratedIndex + 1))
			stack.append(.result([.leaf(self.tokenization[position].first!.range)]))
		}
	}

}

private final class GrammarResolvingMachine {
	typealias Result = [[(Int, Either<ParsedItem, Terminal>)]]
	
	private enum StackFrame {
		case result(Result)
		case terminal(Terminal, unresolved: ArraySlice<Symbol>, position: Int)
		case nonTerminal(NonTerminal, unresolved: ArraySlice<Symbol>, position: Int, resultCollecor: Result, iteratedIndex: Int)
	} 

	private let stateCollection: [[ParsedItem]]
	private let tokenization: [[(terminal: Terminal, range: Range<String.Index>)]]
	private let rootItem: ParsedItem
	private let startIndex: Int
	private let ignoreAmbiguousItems: Bool

	private var stack = [StackFrame]()

	init(
		stateCollection: [[ParsedItem]],
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


	func resolve(unresolved: ArraySlice<Symbol>, position: Int) -> Result {
		appendNew(unresolved: unresolved, position: position)
		return runMachine()
	}


	private func runMachine() -> Result {
		var currentResult: Result?

		while let currentFrame = stack.popLast() {
			switch currentFrame {
			case .result(let result):
				currentResult = result
			case let .terminal(terminal, unresolved: unresolved, position: position):
				resolveTerminal(terminal, unresolved: unresolved, position: position, result: currentResult)
				currentResult = nil
			case let .nonTerminal(nonTerminal, unresolved: unresolved, position: position, resultCollecor: resultCollecor, iteratedIndex: iteratedIndex):
				resolveNonTerminal(nonTerminal, unresolved: unresolved, position: position, resultCollecor: resultCollecor, iteratedIndex: iteratedIndex, result: currentResult)
				currentResult = nil
			}
		}

		// Result may never be nil!
		return currentResult!
	}

	private func appendNew(unresolved: ArraySlice<Symbol>, position: Int) {
		guard position <= rootItem.completedIndex else {
			stack.append(.result([]))
			return
		}
		switch unresolved.first {
		case nil:
			stack.append(.result(position == rootItem.completedIndex ? [[]] : []))
		case .nonTerminal(let nonTerminal)?:
			stack.append(.nonTerminal(nonTerminal, unresolved: unresolved, position: position, resultCollecor: Result(), iteratedIndex: 0))
		case .terminal(let terminal)?:
			stack.append(.terminal(terminal, unresolved: unresolved, position: position))
		}
	}

	private func resolveTerminal(_ terminal: Terminal, unresolved: ArraySlice<Symbol>, position: Int, result: Result?) {
		if let result = result {
			stack.append(.result(result.map{$0 + [(position, .second(terminal))]}))
			return
		}

		// A terminal can only be scanned if there is at least one token left.
		guard position < tokenization.count else {
			stack.append(.result([]))
			return
		}
		// The position might be wrong, so we check that the terminal actually occurred at the current position
		guard tokenization[position].contains(where: {$0.terminal == terminal}) else {
			stack.append(.result([]))
			return
		}
		// Try to resolve the rest.
		stack.append(.terminal(terminal, unresolved: unresolved, position: position))
		appendNew(unresolved: unresolved.dropFirst(), position: position + 1)
	}

	private func resolveNonTerminal(_ nonTerminal: NonTerminal, unresolved: ArraySlice<Symbol>, position: Int, resultCollecor: Result, iteratedIndex: Int, result: Result?) {
		guard !ignoreAmbiguousItems || result == nil || result?.isEmpty == true else {
			let candidate = stateCollection[position][iteratedIndex - 1]
			stack.append(.result(result!.map{$0 + [(position, .first(candidate))]}))
			return
		}

		var newCollector = resultCollecor
		if let result = result {
			let candidate = stateCollection[position][iteratedIndex - 1]
			newCollector += result.map{$0 + [(position, .first(candidate))]}
		} 

		if stateCollection[position].count > iteratedIndex {
			for index in iteratedIndex..<stateCollection[position].count {
				let iteratedCandidate = stateCollection[position][index]

				guard iteratedCandidate.production.pattern == nonTerminal
					&& (iteratedCandidate != self.rootItem || self.startIndex != position)
					&& iteratedCandidate.completedIndex <= self.rootItem.completedIndex 
				else {
					continue
				}
				stack.append(.nonTerminal(
					nonTerminal, 
					unresolved: unresolved, 
					position: position, 
					resultCollecor: newCollector, 
					iteratedIndex: index + 1
				))
				appendNew(unresolved: unresolved.dropFirst(), position: iteratedCandidate.completedIndex)
				return
			}
		}

		stack.append(.result(newCollector))
	}
}
