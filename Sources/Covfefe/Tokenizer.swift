//
//  Tokenizer.swift
//  Covfefe
//
//  Created by Palle Klewitz on 15.08.17.
//

import Foundation

/// A string tokenizer which tokenizes a string based on final productions of a context free grammar
public protocol Tokenizer {
	
	/// Tokenizes the given word and returns a sequence of possible tokens for each unit of the string
	///
	/// For a grammar
	///
	///     A -> a | A B
	///     B -> a | B b
	///
	/// and a string "ab"
	///
	/// The tokenizer generates the tokenization
	///
	///     [[A -> a, B -> a], [B -> b]]
	///
	/// - Parameter word: Word which should be tokenized
	/// - Returns: Tokenization of the word
	/// - Throws: A syntax error if the word could not be tokenized according to rules of the recognized language
	func tokenize(_ word: String) throws -> [[SyntaxTree<Production, Range<String.Index>>]]
}

/// A simple tokenizer which uses a chomsky normalized grammar for tokenization
public struct DefaultTokenizer: Tokenizer {
	
	/// Final productions of the chomsky normalized grammar recognized by this tokenizer
	public let productions: [Production]
	
	/// Creates a new tokenizer using a Chomsky normalized grammar
	///
	/// - Parameter grammar: Grammar specifying the rules with which a string should be tokenized.
	public init(grammar: Grammar) {
		self.productions = grammar.chomskyNormalized().productions.filter(\.isFinal).filter{!$0.production.isEmpty}
	}
	
	public func tokenize(_ word: String) throws -> [[SyntaxTree<Production, Range<String.Index>>]] {
		return try tokenize(word: word, from: word.startIndex, partialResult: [])
	}
	
	/// Recursive tokenization function
	///
	/// - Parameters:
	///   - word: Word which should be tokenized
	///   - startIndex: Index from which the tokenization should start
	///   - partialResult: Tokenization of the substring up to the start index
	/// - Returns: A tokenization of the substring starting at the start index
	/// - Throws: A syntax error if the string contained a token which was is not recognized by the tokenizer
	private func tokenize(word: String, from startIndex: String.Index, partialResult: [[SyntaxTree<Production, Range<String.Index>>]]) throws -> [[SyntaxTree<Production, Range<String.Index>>]] {
		if word[startIndex...].isEmpty {
			return partialResult
		}
		let matches = productions.filter { production -> Bool in
			word.hasPrefix(production.generatedTerminals, from: startIndex)
		}
		guard let first = matches.first, let firstMatchRange = word.rangeOfPrefix(first.generatedTerminals, from: startIndex) else {
			throw SyntaxError(range: startIndex ..< word.endIndex, reason: .unknownToken)
		}
		
		let matchTrees = matches.flatMap { production -> SyntaxTree<Production, Range<String.Index>>? in
			SyntaxTree(key: production, children: [SyntaxTree(value: firstMatchRange)])
		}
		return try tokenize(word: word, from: firstMatchRange.upperBound,partialResult: partialResult + [matchTrees])
	}
}
