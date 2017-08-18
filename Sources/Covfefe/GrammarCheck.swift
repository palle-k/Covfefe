//
//  GrammarCheck.swift
//  Covfefe
//
//  Created by Palle Klewitz on 16.08.17.
//

import Foundation

public extension Grammar {
	
	/// Non-terminals which cannot be reached from the start non-terminal
	public var unreachableNonTerminals: Set<NonTerminal> {
		let productionSet = productions.collect(Set.init)
		let reachableProductions = Grammar.eliminateUnusedProductions(productions: productions, start: start).collect(Set.init)
		return productionSet.subtracting(reachableProductions).map(\.pattern).collect(Set.init)
	}
	
	/// Nonterminals which can never produce a sequence of terminals
	/// because of infinite recursion.
	public var unterminatedNonTerminals: Set<NonTerminal> {
		guard isInChomskyNormalForm else {
			return self.chomskyNormalized().unterminatedNonTerminals
		}
		let nonTerminalProductions = Dictionary(grouping: self.productions, by: {$0.pattern})
		return nonTerminalProductions.filter { _, prod -> Bool in
			return prod.allMatch {!$0.isFinal}
		}.keys.collect(Set.init)
	}
}
