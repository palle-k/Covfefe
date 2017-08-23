//
//  PrefixGrammar.swift
//  Covfefe
//
//  Created by Palle Klewitz on 16.08.17.
//

import Foundation

public extension Grammar {
	
	/// Generates a grammar which recognizes all prefixes of the original grammar.
	///
	/// For example if a grammar would generate `a*(b+c)`,
	/// the prefix grammar would generate the empty string, `a`, `a*`, `a*(`, `a*(b`
	/// `a*(b+` `a*(b+c` and `a*(b+c)`
	///
	/// - Returns: A grammar generating all prefixes of the original grammar
	public func prefixGrammar() -> Grammar {
		let prefixProductions = productions.flatMap { (production) -> [Production] in
			let prefixes = production.production.prefixes().map { sequence -> [Symbol] in
				guard let last = sequence.last else {
					return sequence
				}
				guard case .nonTerminal(let nonTerminal) = last else {
					return sequence
				}
				return sequence.dropLast() + [.nonTerminal(NonTerminal(name: "\(nonTerminal.name)-pre"))]
			} + []
			
			return prefixes.map {Production(pattern: NonTerminal(name: "\(production.pattern)-pre"), production: $0)}
		}
		return Grammar(
			productions: self.productions + prefixProductions + (NonTerminal(name: "\(self.start)-pre-start") --> n("\(self.start.name)-pre") <|> .nonTerminal(self.start)),
			start: NonTerminal(name: "\(self.start)-pre-start"),
			normalizationNonTerminals: self.normalizationNonTerminals
		)
	}
}
