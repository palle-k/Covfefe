//
//  Normalization.swift
//  Grammar
//
//  Created by Palle Klewitz on 11.08.17.
//

import Foundation

extension Grammar {
	static func makeChomskyNormalForm(of productions: [Production], start: NonTerminal) -> Grammar {
		
		// Generate weak Chomsky Normal Form by eliminating all productions generating a pattern of nonTerminals mixed with terminals
		let nonMixedProductions = productions.flatMap { production -> [Production] in
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
		
		// All productions for a given non terminal pattern
		let nonTerminalProductions = Dictionary(grouping: nonMixedProductions) { production in
			production.pattern
		}
		
		// Determine which non terminals can produce an empty string
		let nonTerminalProducesEmpty = nonTerminalProductions.mapValues { productions -> Bool in
			productions.contains(where: {$0.production.isEmpty})
		}
		let producedNonTerminals = nonTerminalProductions.mapValues { productions -> Set<NonTerminal> in
			productions.flatMap(\.generatedNonTerminals).collect(Set.init)
		}
		
		let producedBy = Dictionary(
			uniqueKeysWithValues: producedNonTerminals.keys.map { pattern -> (NonTerminal, Set<NonTerminal>) in
				(pattern, producedNonTerminals.filter{$0.value.contains(pattern)}.keys.collect(Set.init))
			}
		)
		
		
		
		fatalError("TODO")
	}
}
