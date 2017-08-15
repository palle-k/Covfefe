//
//  Tokenizer.swift
//  Covfefe
//
//  Created by Palle Klewitz on 15.08.17.
//

import Foundation

public protocol Tokenizer {
	func tokenize(_ word: String) throws -> [[SyntaxTree<Production, Range<String.Index>>]]
}

public class DefaultTokenizer: Tokenizer {
	public let grammar: Grammar
	
	public init(grammar: Grammar) {
		self.grammar = grammar
	}
	
	public func tokenize(_ word: String) throws -> [[SyntaxTree<Production, Range<String.Index>>]] {
		let finalProductions = grammar.chomskyNormalized().productions.filter(\.isFinal).filter{!$0.production.isEmpty}
		return try tokenize(word: word, from: word.startIndex, finalProductions: finalProductions)
	}
	
	private func tokenize(word: String, from startIndex: String.Index, finalProductions: [Production]) throws -> [[SyntaxTree<Production, Range<String.Index>>]] {
		if word[startIndex...].isEmpty {
			return []
		}
		let matches = finalProductions.filter { production -> Bool in
			word.hasPrefix(production.generatedTerminals, from: startIndex)
		}
		guard let first = matches.first, let firstMatchRange = word.rangeOfPrefix(first.generatedTerminals, from: startIndex) else {
			throw SyntaxError.unknownSequence(from: String(word[startIndex...]))
		}
		
		let restTokenization = try tokenize(word: word, from: firstMatchRange.upperBound, finalProductions: finalProductions)
		let matchTrees = matches.flatMap { production -> SyntaxTree<Production, Range<String.Index>>? in
			SyntaxTree(key: production, children: [SyntaxTree(value: firstMatchRange)])
		}
		//TODO: Make this method tail recursive
		return [matchTrees] + restTokenization
	}
}
