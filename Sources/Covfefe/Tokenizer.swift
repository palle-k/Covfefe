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

public struct DefaultTokenizer: Tokenizer {
	public let productions: [Production]
	
	public init(grammar: Grammar) {
		self.productions = grammar.chomskyNormalized().productions.filter(\.isFinal).filter{!$0.production.isEmpty}
	}
	
	public func tokenize(_ word: String) throws -> [[SyntaxTree<Production, Range<String.Index>>]] {
		return try tokenize(word: word, from: word.startIndex, partialResult: [])
	}
	
	private func tokenize(word: String, from startIndex: String.Index, partialResult: [[SyntaxTree<Production, Range<String.Index>>]]) throws -> [[SyntaxTree<Production, Range<String.Index>>]] {
		if word[startIndex...].isEmpty {
			return partialResult
		}
		let matches = productions.filter { production -> Bool in
			word.hasPrefix(production.generatedTerminals, from: startIndex)
		}
		guard let first = matches.first, let firstMatchRange = word.rangeOfPrefix(first.generatedTerminals, from: startIndex) else {
			throw SyntaxError.unknownSequence(from: String(word[startIndex...]))
		}
		
		let matchTrees = matches.flatMap { production -> SyntaxTree<Production, Range<String.Index>>? in
			SyntaxTree(key: production, children: [SyntaxTree(value: firstMatchRange)])
		}
		return try tokenize(word: word, from: firstMatchRange.upperBound,partialResult: partialResult + [matchTrees])
	}
}
