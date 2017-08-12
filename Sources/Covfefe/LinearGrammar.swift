//
//  Productions.swift
//  Covfefe
//
//  Created by Palle Klewitz on 07.08.17.
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

public struct LinearGrammar {
	public struct InvalidGrammarError: Error, CustomStringConvertible {
		public let invalidProduction: Production
		public let description: String
	}
	
	public let productions: [NonTerminal: [Production]]
	public let start: NonTerminal
	
	public init(productions: [Production], start: NonTerminal) throws {
		if let firstNonRightLinearProduction = productions.first(where: { production -> Bool in
			!production.isLinear
		}) {
			throw InvalidGrammarError(invalidProduction: firstNonRightLinearProduction, description: "Production does not satisfy pattern (NonTerminal -> empty | Terminal | Terminal NonTerminal)")
		}
		self.productions = Dictionary(grouping: productions, by: {$0.pattern})
		self.start = start
	}
	
	public func contains(word: String) -> Bool {
		func contains(word: String, startingAt start: NonTerminal) -> Bool {
			let possibleProductions = productions[start, default: []].filter {$0.canGenerateSubstring(of: word)}
			
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
		
		return contains(word: word, startingAt: start)
	}
	
	public func generateSyntaxTree(for word: String) -> String? {
		func explain(word: String, startingAt start: NonTerminal) -> String? {
			let possibleProductions = productions[start, default: []].filter {$0.canGenerateSubstring(of: word)}
			
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
		
		return explain(word: word, startingAt: start)
	}
}

extension LinearGrammar: CustomStringConvertible {
	public var description: String {
		return """
		LinearGrammar(
		\(productions.values.flatMap{$0}.map{"\t\($0.description)"}.joined(separator: ",\n"))
		)
		"""
	}
}
