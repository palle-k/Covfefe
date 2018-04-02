//
//  CYKParser.swift
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


/// A parser based on the CYK algorithm.
///
/// The parser can parse non-deterministic and deterministic grammars.
/// It requires O(n^3) runtime.
///
/// For ambiguous grammars, the runtime for parses may increase,
/// as some expressions have exponentially many possible parse trees depending on expression length.
/// This exponential growth can be avoided by only generating a single parse tree with `syntaxTree(for:)`.
///
/// For unambiguous grammars, the Earley parser should be used instead, as it has linear or quadratic runtime.
///
/// The original CYK parsing can only recognize grammars in Chomsky normal form.
/// This parser automatically transforms the recognized grammar into Chomsky normal form
/// and transforms the parse tree back to the original grammar. Nullable items are ommited in the
/// parse tree of the CYK parser.
public struct CYKParser: AmbiguousGrammarParser {
	
	/// The grammar which the parser recognizes
	public let grammar: Grammar
	
	/// The parser requires the grammar to be in chomsky normal form
	private let normalizedGrammar: Grammar
	
	// In CYK parsing, no intelligent tokenizing is possible. A standard tokenizer is used instead.
	private let tokenizer: Tokenizer
	
	/// Initializes a CYK parser which recognizes the given grammar.
	///
	/// The parser can parse non-deterministic and deterministic context free languages in O(n^3).
	///
	/// - Parameter grammar: The grammar which the parser recognizes.
	public init(grammar: Grammar) {
		self.grammar = grammar
		self.normalizedGrammar = grammar.chomskyNormalized()
		self.tokenizer = DefaultTokenizer(grammar: grammar)
	}
	
	/// Generates an error from a CYK table if the grammar cannot be used to generate a given word.
	///
	/// - Parameter cykTable: Table containing unfinished syntax trees
	/// - Returns: An error pointing towards the first invalid token in the string.
	private func generateError(_ cykTable: Array<[[SyntaxTree<Production, Range<String.Index>>]]>, string: String) -> SyntaxError {
		let memberRows = (0..<cykTable.count).map { columnIndex -> Int? in
			(0 ..< (cykTable.count - columnIndex)).reduce(nil) { maxIndex, rowIndex -> Int? in
				if cykTable[rowIndex][columnIndex].contains(where: { tree -> Bool in
					tree.root?.pattern == normalizedGrammar.start
				}) {
					return rowIndex
				}
				return maxIndex
			}
		}
		
		if let firstMember = memberRows[0] {
			return SyntaxError(range: cykTable[0][firstMember+1][0].leafs.first!, in: string, reason: .unmatchedPattern)
		} else {
			return SyntaxError(range: cykTable[0][0][0].leafs.first!, in: string, reason: .unmatchedPattern)
		}
	}
	
	/// Reintroduces chain productions which have been eliminated during normalization
	///
	/// - Parameter tree: Syntax tree without chain productions
	/// - Returns: Syntax tree with chain productions added.
	private func unfoldChainProductions(_ tree: SyntaxTree<Production, Range<String.Index>>) -> ParseTree {
		switch tree {
		case .leaf(let leaf):
			return .leaf(leaf)
			
		case .node(key: let production, children: let children):
			guard let chain = production.nonTerminalChain else {
				return .node(key: production.pattern, children: children.map(unfoldChainProductions))
			}
			let newNode = chain.reversed().reduce(children.map(unfoldChainProductions)) { (childNodes, nonTerminal) -> [ParseTree] in
				[SyntaxTree.node(key: nonTerminal, children: childNodes)]
			}
			return .node(key: production.pattern, children: newNode)
		}
	}

	private func syntaxTree(for string: String, ignoreAmbiguousItems: Bool) throws -> [ParseTree] {
		let tokens = try self.tokenizer.tokenize(string)
		if tokens.isEmpty {
			if normalizedGrammar.productions.contains(where: { production -> Bool in
				production.pattern == normalizedGrammar.start
					&& production.generatesEmpty(in: normalizedGrammar)
			}) {
				return [SyntaxTree.node(key: normalizedGrammar.start, children: [SyntaxTree.leaf(string.startIndex ..< string.endIndex)])]
			} else {
				throw SyntaxError(range: string.startIndex ..< string.endIndex, in: string, reason: .emptyNotAllowed)
			}
		}
		
		let terminalProductions = normalizedGrammar.productions.filter{$0.isFinal}.filter {!$0.production.isEmpty}
		let startTrees = tokens.map { alternatives -> [SyntaxTree<Production, Range<String.Index>>] in
			alternatives.flatMap { token -> [SyntaxTree<Production, Range<String.Index>>] in
				terminalProductions.filter { production in
					production.generatedTerminals[0] == token.terminal
				}.map { production -> SyntaxTree<Production, Range<String.Index>> in
					SyntaxTree.node(key: production, children: [SyntaxTree.leaf(token.range)])
				}
			}
		}
		
		let nonTerminalProductions = Dictionary(grouping: normalizedGrammar.productions.filter{!$0.isFinal}) { production -> NonTerminalString in
			NonTerminalString(characters: production.generatedNonTerminals)
		}
		
		var cykTable = [[[SyntaxTree<Production, Range<String.Index>>]]](repeating: [], count: startTrees.count)
		cykTable[0] = startTrees
		
		for row in 1 ..< cykTable.count {
			let upperBound = cykTable.count - row
			
			cykTable[row] = (0..<upperBound).map { column -> [SyntaxTree<Production, Range<String.Index>>] in
				let cell = (1...row).flatMap { offset -> [SyntaxTree<Production, Range<String.Index>>] in
					let ref1Row = row - offset
					let ref2Col = column + row - offset + 1
					let ref2Row = offset - 1
					
					return crossFlatMap(cykTable[ref1Row][column], cykTable[ref2Row][ref2Col]) { leftTree, rightTree -> [SyntaxTree<Production, Range<String.Index>>] in
						let combinedString = NonTerminalString(characters: [leftTree.root!.pattern, rightTree.root!.pattern])
						let possibleProductions = nonTerminalProductions[combinedString, default: []]
						return possibleProductions.map { pattern -> SyntaxTree<Production, Range<String.Index>> in
							return SyntaxTree(key: pattern, children: [leftTree, rightTree])
						}
					}
				}
				if ignoreAmbiguousItems {
					return cell.unique(by: {$0.root!.pattern}).collect(Array.init)
				} else {
					return cell
				}
			}
		}
		
		// If a given word is not a member of the language generated by this grammar
		// an error will be computed that returns the first and largest structure
		// in the syntax tree that the parser was unable to process.
		let syntaxTrees = cykTable[cykTable.count-1][0].filter { tree -> Bool in
			tree.root?.pattern == normalizedGrammar.start
		}
		if syntaxTrees.isEmpty {
			throw generateError(cykTable, string: string)
		}
		return syntaxTrees.map{unfoldChainProductions($0).explode(normalizedGrammar.utilityNonTerminals.contains)[0]}
	}
	
	/// Creates a syntax tree which explains how a word was derived from a grammar
	///
	/// - Parameter string: Input word, for which a parse tree should be generated
	/// - Returns: A syntax tree explaining how the grammar can be used to derive the word described by the given tokenization
	/// - Throws: A syntax error if the word is not in the language recognized by the parser
	public func syntaxTree(for string: String) throws -> ParseTree {
		return try self.syntaxTree(for: string, ignoreAmbiguousItems: true)[0]
	}
	
	/// Generates all syntax trees explaining how a word can be derived from a grammar.
	///
	/// This function should only be used for ambiguous grammars and if it is necessary to
	/// retrieve all parse trees, as it comes with an additional cost in runtime.
	///
	/// For unambiguous grammars, this function should return the same results as `syntaxTree(for:)`.
	///
	/// - Parameter string: Input word, for which all parse trees should be generated
	/// - Returns: All syntax trees which explain how the input was derived from the recognized grammar
	/// - Throws: A syntax error if the word is not in the language recognized by the parser
	public func allSyntaxTrees(for string: String) throws -> [ParseTree] {
		return try self.syntaxTree(for: string, ignoreAmbiguousItems: false)
	}
}
