//
//  Tokenizer.swift
//  Covfefe
//
//  Created by Palle Klewitz on 15.08.17.
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

/// A string tokenizer which tokenizes a string based on final productions of a context free grammar.
public protocol Tokenizer {

	/// Tokenizes the given word and returns a sequence of possible tokens for each unit of the string
	///
	/// For a grammar
	///
	///		A -> a | A B
	///		B -> a | B b
	///
	/// and a string "ab"
	///
	/// The tokenizer generates the tokenization
	///
	///		[[a], [b]]
	///
	/// - Parameter word: Word which should be tokenized
	/// - Returns: Tokenization of the word
	/// - Throws: A syntax error if the word could not be tokenized according to rules of the recognized language
	func tokenize(_ word: String) throws -> [[(terminal: Terminal, range: Range<String.Index>)]]
}

/// A simple tokenizer which uses a all terminals in a grammar for tokenization.
///
/// Terminals may not overlap partially.
/// If two terminals, `ab` and `bc` exist and `abc` is tokenized,
/// the tokenizer will not find an occurrence of the second terminal.
public struct DefaultTokenizer: Tokenizer {
	
	/// All terminals which the tokenizer can recognize
	private let terminals: [Terminal]
	
	/// Creates a new tokenizer using a Chomsky normalized grammar
	///
	/// - Parameter grammar: Grammar specifying the rules with which a string should be tokenized.
	public init(grammar: Grammar) {
		self.terminals = grammar.productions.flatMap{$0.generatedTerminals}
	}
	
	/// Tokenizes the given word and returns a sequence of possible tokens for each unit of the string
	///
	/// For a grammar
	///
	///		A -> a | A B
	///		B -> a | B b
	///
	/// and a string "ab"
	///
	/// The tokenizer generates the tokenization
	///
	///		[[a], [b]]
	///
	/// - Parameter word: Word which should be tokenized
	/// - Returns: Tokenization of the word
	/// - Throws: A syntax error if the word could not be tokenized according to rules of the recognized language
	public func tokenize(_ word: String) throws -> [[(terminal: Terminal, range: Range<String.Index>)]] {
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
	private func tokenize(word: String, from startIndex: String.Index, partialResult: [[(Terminal, Range<String.Index>)]]) throws -> [[(terminal: Terminal, range: Range<String.Index>)]] {
		if word[startIndex...].isEmpty {
			return partialResult
		}
		let matches = terminals.filter { terminal -> Bool in
			word.hasPrefix(terminal, from: startIndex)
		}
		guard
			let first = matches.first,
			let firstMatchRange = word.rangeOfPrefix(first, from: startIndex)
		else {
			throw SyntaxError(range: startIndex ..< word.endIndex, in: word, reason: .unknownToken)
		}
		
		let terminalRanges = matches.map{($0, firstMatchRange)}
		return try tokenize(word: word, from: firstMatchRange.upperBound, partialResult: partialResult + [terminalRanges])
	}
}
