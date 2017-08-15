//
//  LinearParser.swift
//  Covfefe
//
//  Created by Palle Klewitz on 15.08.17.
//

import Foundation

public class LinearParser {
	public let grammar: Grammar
	
	public init(grammar: Grammar) {
		assert(grammar.productions.allMatch{$0.isLinear}, "LinearParser can only recognize linear grammars.")
		self.grammar = grammar
	}
	
	public func recognizes(word: String) -> Bool {
		let nonTerminalProductions = Dictionary(grouping: grammar.productions, by: {$0.pattern})
		func contains(word: String, startingAt start: NonTerminal) -> Bool {
			let possibleProductions = nonTerminalProductions[start, default: []].filter {$0.canGenerateSubstring(of: word)}
			
			return possibleProductions.contains { production -> Bool in
				if production.canFullyGenerate(word: word) {
					return true
				}
				let unexplainedSubstring = production.removingGeneratedSubstring(from: word)
				guard let nonTerminal = production.generatedNonTerminals.first else {
					return false
				}
				return contains(word: unexplainedSubstring, startingAt: nonTerminal)
			}
		}
		
		return contains(word: word, startingAt: grammar.start)
	}
	
	public func syntaxTree(for word: String) -> String? {
		let nonTerminalProductions = Dictionary(grouping: grammar.productions, by: {$0.pattern})
		func explain(word: String, startingAt start: NonTerminal) -> String? {
			let possibleProductions = nonTerminalProductions[start, default: []].filter {$0.canGenerateSubstring(of: word)}
			
			return possibleProductions.flatMap { production -> String? in
				if production.canFullyGenerate(word: word) {
					return production.pattern.name
				}
				let unexplainedSubstring = production.removingGeneratedSubstring(from: word)
				guard let nonTerminal = production.generatedNonTerminals.first else {
					return nil
				}
				guard let substringExplanation = explain(word: unexplainedSubstring, startingAt: nonTerminal) else {
					return nil
				}
				return "\(start.name) --> \(substringExplanation)"
			}.first
		}
		
		return explain(word: word, startingAt: grammar.start)
	}
}
