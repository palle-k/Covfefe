//
//  Normalization.swift
//  ContextFree
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
				return (NonTerminal(name: "\(production.pattern.name)_\(terminal.value)_\(offset)"))
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
					pattern: NonTerminal(name: "\(production.pattern.name)_\(nonTerminal.name)\(offset)"),
					production: [.nonTerminal(nonTerminal), n("\(production.pattern.name)_\(next.name)\(offset + 1)")]
				)
			}
			
			let lastProduction = Production(
				pattern: NonTerminal(name: "\(production.pattern.name)_\(production.generatedNonTerminals.dropLast().last!.name)\(production.generatedNonTerminals.count-2)"),
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
			if state[pattern]! || path.contains(pattern) {
				return state
			}
			
			let reachableNonTerminals = nonTerminalProductions[pattern]!.map { $0.generatedNonTerminals.collect(Set.init) }.reduce(Set()) { $0.union($1) }
			if reachableNonTerminals.contains(where: {state[$0]!}) {
				var mutableState = state
				mutableState[pattern] = true
				return mutableState
			} else {
				return reachableNonTerminals.reduce(state) { (partialState, nonTerminal) -> Dictionary<NonTerminal, Bool> in
					guard !partialState[pattern]! else {
						return partialState
					}
					return canProduceNonEmpty(pattern: nonTerminal, path: path.union([pattern]), state: partialState)
				}
			}
		}
		
		let nonTerminalCanProduceNonEmpty = nonTerminalProductions.keys.reduce(
			nonTerminalProductions.mapValues{$0.contains{!$0.production.isEmpty}}
		) { partialResult, nonTerminal -> Dictionary<NonTerminal, Bool> in
			canProduceNonEmpty(pattern: nonTerminal, path: [], state: partialResult)
		}
		
		return productions.flatMap { production -> Production? in
			if production.production.isEmpty {
				return production.pattern == start ? production : nil
			} else if production.isFinal {
				return production
			}
			
			let filteredProduction = production.generatedNonTerminals.filter {nonTerminalCanProduceNonEmpty[$0]!}
			
			if !filteredProduction.isEmpty {
				return Production(pattern: production.pattern, production: filteredProduction.map{.nonTerminal($0)})
			} else {
				return nil
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
			let reachableProductions = nonTerminalProductions[nonTerminal]!
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
	
	
	public static func makeChomskyNormalForm(of productions: [Production], start: NonTerminal) -> Grammar {
		
		// Generate weak Chomsky Normal Form by eliminating all productions generating a pattern of nonTerminals mixed with terminals
		let nonMixedProductions = eliminateMixedProductions(productions: productions)
		
		// Decompose all productions with three or more nonTerminals
		let decomposedProductions = decomposeProductions(productions: nonMixedProductions)
		
		// Remove empty productions
		let nonEmptyProductions = eliminateEmptyProductions(productions: decomposedProductions, start: start)
		
		// Remove chains
		let nonChainedProductions = eliminateChainProductions(productions: nonEmptyProductions)
		
		// Remove duplicates
		let uniqueProductions = nonChainedProductions.uniqueElements().collect(Array.init)
		
		// Remove unreachable productions
		let reachableProductions = eliminateUnusedProductions(productions: uniqueProductions, start: start)
		
		let initialNonTerminals = productions.flatMap{[$0.pattern] + $0.generatedNonTerminals}.collect(Set.init)
		let generatedNonTerminals = reachableProductions.flatMap{[$0.pattern] + $0.generatedNonTerminals}.collect(Set.init)
		let newNonTerminals = generatedNonTerminals.subtracting(initialNonTerminals)
		
		return Grammar(productions: reachableProductions, start: start, normalizationNonTerminals: newNonTerminals)
	}
}
