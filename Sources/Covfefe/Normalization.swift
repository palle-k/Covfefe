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
			let enumeratedTerminals = production.production.enumerated().compactMap { offset, element -> (Int, Terminal)? in
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
	
	static func eliminateEmpty(productions: [Production], start: NonTerminal) -> [Production] {
		let groupedProductions = Dictionary(grouping: productions, by: {$0.pattern})
		
		func generatesEmpty(_ nonTerminal: NonTerminal, path: Set<NonTerminal>) -> Bool {
			if path.contains(nonTerminal) {
				return false
			}
			
			let directProductions = groupedProductions[nonTerminal, default: []]
			return directProductions.contains { production -> Bool in
				if production.production.isEmpty {
					return true
				}
				return production.generatedNonTerminals.count == production.production.count
                    && production.generatedNonTerminals.allSatisfy { pattern -> Bool in
						generatesEmpty(pattern, path: path.union([nonTerminal]))
					}
			}
		}
		
		func generatesNonEmpty(_ nonTerminal: NonTerminal, path: Set<NonTerminal>) -> Bool {
			if path.contains(nonTerminal) {
				return false
			}
			
			let directProductions = groupedProductions[nonTerminal, default: []]
			return directProductions.contains { production -> Bool in
				if !production.generatedTerminals.isEmpty {
					return true
				}
				return production.generatedNonTerminals.contains { pattern -> Bool in
					generatesNonEmpty(pattern, path: path.union([nonTerminal]))
				}
			}
		}
		
		let result = Dictionary(uniqueKeysWithValues: groupedProductions.keys.map { key -> (NonTerminal, (generatesEmpty: Bool, generatesNonEmpty: Bool)) in
			(key, (generatesEmpty: generatesEmpty(key, path: []), generatesNonEmpty: generatesNonEmpty(key, path: [])))
		})
		
		let updatedProductions = productions.flatMap { production -> [Production] in
			if production.production.isEmpty && production.pattern != start {
				return []
			}
			if production.isFinal {
				return [production]
			}
			let produced = production.production.reduce([[]]) { (partialResult, symbol) -> [[Symbol]] in
				if case .nonTerminal(let nonTerminal) = symbol {
					let (empty, nonEmpty) = result[nonTerminal] ?? (false, true)
					
					if !nonEmpty {
						return partialResult
					} else if !empty {
						return partialResult.map {$0 + [symbol]}
					} else {
						return partialResult + partialResult.map {$0 + [symbol]}
					}
				} else {
					return partialResult.map {$0 + [symbol]}
				}
			}
			return produced.compactMap { sequence -> Production? in
				guard !sequence.isEmpty || production.pattern == start else {
					return nil
				}
				return Production(pattern: production.pattern, production: sequence)
			}
		}
		return updatedProductions
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
			let reachableProductions = nonTerminalProductions[nonTerminal] ?? []
			
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
	
	/// Generates a context free grammar equal to the current grammar which is in Chomsky Normal Form.
	/// The grammar is converted by decomposing non-terminal productions of lengths greater than 2,
	/// introducing new non-terminals to replace terminals in mixed productions, and removing empty productions.
	///
	/// Chomsky normal form is required for some parsers (like the CYK parser) to work.
	///
	/// In chomsky normal form, all productions must have the following form:
	///
	/// 	A -> B C
	/// 	D -> x
	/// 	Start -> empty
	///
	/// Note that empty productions are only allowed starting from the start non-terminal
	///
	/// - Returns: Chomsky normal form of the current grammar
	public func chomskyNormalized() -> Grammar {
		// Generate weak Chomsky Normal Form by eliminating all productions generating a pattern of nonTerminals mixed with terminals
		let nonMixedProductions = Grammar.eliminateMixedProductions(productions: productions)
		
		// Decompose all productions with three or more nonTerminals
		let decomposedProductions = Grammar.decomposeProductions(productions: nonMixedProductions)
		
		// Remove empty productions
		let nonEmptyProductions = Grammar.eliminateEmpty(productions: decomposedProductions, start: start)
		
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
		
		return Grammar(productions: reachableProductions, start: start, utilityNonTerminals: self.utilityNonTerminals.union(newNonTerminals))
	}
}
