//
//  Normalization.swift
//  Covfefe
//
//  Created by Palle Klewitz on 11.08.17.
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

extension Grammar {
	
	static func eliminateMixedProductions(productions: [Production]) -> [Production] {
		return productions.flatMap { production -> [Production] in
			// Determine, if the production is invalid and if not, return early
			let terminals = production.generatedTerminals
			let nonTerminals = production.generatedNonTerminals
			
			if terminals.isEmpty {
				return [production]
			}
			if nonTerminals.isEmpty && terminals.count == 1 {
				return [production]
			}
			
			// Find all terminals and their indices in the production
			let enumeratedTerminals = production.production.enumerated().flatMap { offset, element -> (Int, Terminal)? in
				guard case .terminal(let terminal) = element else {
					return nil
				}
				return (offset, terminal)
			}
			
			// Generate new patterns which replace the terminals in the existing production
			let patterns = enumeratedTerminals.map { element -> NonTerminal in
				let (offset, terminal) = element
				return NonTerminal(name: "\(production.pattern.name)-\(String(terminal.hashValue % 65526, radix: 16, uppercase: false))-\(offset)")
			}
			
			// Update the existing production by replacing all terminals with the new patterns
			let updatedProductionElements = zip(enumeratedTerminals, patterns).map{($0.0, $0.1, $1)}.reduce(production.production) { productionElements, element -> [Symbol] in
				let (offset, _, nonTerminal) = element
				var updatedElements = productionElements
				updatedElements[offset] = .nonTerminal(nonTerminal)
				return updatedElements
			}
			
			let updatedProduction = Production(pattern: production.pattern, production: updatedProductionElements)
			
			// Generate new productions which produce the replaced terminals
			let newProductions = zip(enumeratedTerminals, patterns).map{($0.0, $0.1, $1)}.map { element -> Production in
				let (_, terminal, nonTerminal) = element
				return Production(pattern: nonTerminal, production: [.terminal(terminal)])
			}
			
			return newProductions + [updatedProduction]
		}
	}
	
	static func decomposeProductions(productions: [Production]) -> [Production] {
		return productions.flatMap { production -> [Production] in
			guard production.generatedNonTerminals.count >= 3 else {
				return [production]
			}
			let newProductions = production.generatedNonTerminals.dropLast().pairs().enumerated().map { element -> Production in
				let (offset, (nonTerminal, next)) = element
				return Production(
					pattern: NonTerminal(name: "\(production.pattern.name)-\(nonTerminal.name)-\(offset)"),
					production: [.nonTerminal(nonTerminal), n("\(production.pattern.name)-\(next.name)-\(offset + 1)")]
				)
			}
			
			let lastProduction = Production(
				pattern: NonTerminal(name: "\(production.pattern.name)-\(production.generatedNonTerminals.dropLast().last!.name)-\(production.generatedNonTerminals.count-2)"),
				production: production.generatedNonTerminals.suffix(2).map{.nonTerminal($0)}
			)
			
			let firstProduction = Production(pattern: production.pattern, production: newProductions[0].production)
			let middleProductions = newProductions.dropFirst().collect(Array.init)
			return [firstProduction] + middleProductions + [lastProduction]
		}
	}
	
	static func eliminateEmptyProductions(productions: [Production], start: NonTerminal) -> [Production] {
		let nonTerminalProductions = Dictionary(grouping: productions, by: {$0.pattern})
		//let nonTerminalProducesCanProduceNonEmpty = nonTerminalProductions.mapValues{$0.contains{!$0.production.isEmpty}}
		
		func canProduceNonEmpty(pattern: NonTerminal, path: Set<NonTerminal>, state: Dictionary<NonTerminal, Bool>) -> Dictionary<NonTerminal, Bool> {
			// Break when a recursive loop has been found
			if state[pattern, default: false] || path.contains(pattern) {
				return state
			}
			
			// Find all non terminals which can be reached from the current non-terminal
			let reachableNonTerminals = nonTerminalProductions[pattern]!.map { $0.generatedNonTerminals.collect(Set.init) }.reduce(Set()) { $0.union($1) }
			
			let updatedState = reachableNonTerminals.reduce(state) { (partialState, nonTerminal) -> Dictionary<NonTerminal, Bool> in
				return canProduceNonEmpty(pattern: nonTerminal, path: path.union([pattern]), state: partialState)
			}
			
			// If any reachable non-terminal can produce a non-empty string, the current non-terminal also can
			if reachableNonTerminals.contains(where: {updatedState[$0]!}) {
				var mutableState = updatedState
				mutableState[pattern] = true
				return mutableState
			}
			return updatedState
		}
		
		func canProduceEmpty(pattern: NonTerminal, path: Set<NonTerminal>, state: Dictionary<NonTerminal, Bool>) -> Dictionary<NonTerminal, Bool> {
			// Return early if the terminal is already known to produce empty or if a loop has been found
			if path.contains(pattern) || state[pattern, default: false] {
				return state
			}
			
			
			let patternProductions = nonTerminalProductions[pattern, default: []]
			if patternProductions.contains(where: { (production) -> Bool in
				production.production.isEmpty
			}) {
				var mutableState = state
				mutableState[pattern] = true
				return mutableState
			}
			
			let reachableNonTerminals = nonTerminalProductions[pattern, default: []].map { $0.generatedNonTerminals.collect(Set.init) }.reduce(Set()) { $0.union($1) }
			
			let updatedState = reachableNonTerminals.reduce(state) { partialResult, nonTerminal -> Dictionary<NonTerminal, Bool> in
				return canProduceEmpty(pattern: nonTerminal, path: path.union([pattern]), state: state)
			}
			
			if reachableNonTerminals.contains(where: {updatedState[$0, default: false]}) {
				var mutableState = updatedState
				mutableState[pattern] = true
				return mutableState
			}
			return updatedState
		}
		
		let nonTerminalCanProduceNonEmpty = nonTerminalProductions.keys.reduce(
			nonTerminalProductions.mapValues {
				$0.contains{!$0.production.isEmpty}
			}
		) { partialResult, nonTerminal -> Dictionary<NonTerminal, Bool> in
			canProduceNonEmpty(pattern: nonTerminal, path: [], state: partialResult)
		}
		
		let nonTerminalCanProduceEmpty = nonTerminalProductions.keys.reduce(
			nonTerminalProductions.mapValues {
				$0.contains(where: {$0.production.isEmpty})
			}
		) { (partialResult, nonTerminal) -> Dictionary<NonTerminal, Bool> in
			canProduceEmpty(pattern: nonTerminal, path: [], state: partialResult)
		}
		
		return productions.flatMap { production -> [Production] in
			if production.production.isEmpty {
				return production.pattern == start ? [production] : []
			} else if production.isFinal {
				return [production]
			}
			
			let filteredProduction = production.generatedNonTerminals.filter {nonTerminalCanProduceNonEmpty[$0] ?? false}
			
			// Productions have already been decomposed, so there can only be one or two non-terminals
			if filteredProduction.count == 2 {
				var partialResult: [Production] = []
				if nonTerminalCanProduceEmpty[filteredProduction[0]]! {
					partialResult += [Production(pattern: production.pattern, production: [.nonTerminal(filteredProduction[1])])]
				}
				if nonTerminalCanProduceEmpty[filteredProduction[1]]! {
					partialResult += [Production(pattern: production.pattern, production: [.nonTerminal(filteredProduction[0])])]
				}
				return partialResult + [Production(pattern: production.pattern, production: filteredProduction.map{.nonTerminal($0)})]
			} else if filteredProduction.count == 1 {
				return [Production(pattern: production.pattern, production: filteredProduction.map{.nonTerminal($0)})]
			} else {
				return []
			}
		}
	}
	
	static func eliminateChainProductions(productions: [Production]) -> [Production] {
		let nonTerminalProductions = Dictionary(grouping: productions, by: {$0.pattern})
		
		func findNonChainProduction(from start: Production, visited: Set<NonTerminal>, path: [NonTerminal]) -> [(Production, [NonTerminal])] {
			if start.isFinal || start.generatedNonTerminals.count != 1 {
				return [(start, path)]
			} else if visited.contains(start.pattern) {
				return []
			}
			
			let nonTerminal = start.generatedNonTerminals[0]
			let reachableProductions = nonTerminalProductions[nonTerminal]!
			
			return reachableProductions.flatMap{findNonChainProduction(from: $0, visited: visited.union([start.pattern]), path: path + [nonTerminal])}
		}
		
		return productions.flatMap { production -> [Production] in
			let nonChainProductions = findNonChainProduction(from: production, visited: [], path: [])
			return nonChainProductions.map { element -> Production in
				let (p, chain) = element
				return Production(pattern: production.pattern, production: p.production, chain: chain)
			}
		}
	}
	
	static func eliminateUnusedProductions(productions: [Production], start: NonTerminal) -> [Production] {
		let nonTerminalProductions = Dictionary(grouping: productions, by: {$0.pattern})
		
		func mark(nonTerminal: NonTerminal, visited: Set<NonTerminal>) -> Set<NonTerminal> {
			if visited.contains(nonTerminal) {
				return visited
			}
			
			let newVisited = visited.union([nonTerminal])
			let reachableProductions = nonTerminalProductions[nonTerminal] ?? []
			return reachableProductions.reduce(newVisited) { partialVisited, production -> Set<NonTerminal> in
				production.generatedNonTerminals.reduce(partialVisited) { partial, n -> Set<NonTerminal> in
					mark(nonTerminal: n, visited: partial)
				}
			}
		}
		
		let reachableNonTerminals = mark(nonTerminal: start, visited: [])
		
		return productions.filter { production -> Bool in
			reachableNonTerminals.contains(production.pattern)
		}
	}
	
	public func chomskyNormalized() -> Grammar {
		// Generate weak Chomsky Normal Form by eliminating all productions generating a pattern of nonTerminals mixed with terminals
		let nonMixedProductions = Grammar.eliminateMixedProductions(productions: productions)
		
		// Decompose all productions with three or more nonTerminals
		let decomposedProductions = Grammar.decomposeProductions(productions: nonMixedProductions)
		
		// Remove empty productions
		let nonEmptyProductions = Grammar.eliminateEmptyProductions(productions: decomposedProductions, start: start)
		
		// Remove chains
		let nonChainedProductions = Grammar.eliminateChainProductions(productions: nonEmptyProductions)
		
		// Remove duplicates
		let uniqueProductions = nonChainedProductions.uniqueElements().collect(Array.init)
		
		// Remove unreachable productions
		let reachableProductions = Grammar.eliminateUnusedProductions(productions: uniqueProductions, start: start)
		//let reachableProductions = uniqueProductions
		
		let initialNonTerminals = productions.flatMap{[$0.pattern] + $0.generatedNonTerminals}.collect(Set.init)
		let generatedNonTerminals = reachableProductions.flatMap{[$0.pattern] + $0.generatedNonTerminals}.collect(Set.init)
		let newNonTerminals = generatedNonTerminals.subtracting(initialNonTerminals)
		
		return Grammar(productions: reachableProductions, start: start, normalizationNonTerminals: newNonTerminals)
	}
}
