//
//  Grammar.swift
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

public enum SyntaxError: Error {
	case unknownSequence(from: String)
	case unmatchedPattern(pattern: SyntaxTree<NonTerminal, Range<String.Index>>)
	case emptyWordNotAllowed
}

public struct Grammar {
	public let productions: [Production]
	public let start: NonTerminal
	private let normalizationNonTerminals: Set<NonTerminal>
	
	public init(productions: [Production], start: NonTerminal) {
		if productions.allMatch({ production -> Bool in
			production.isInChomskyNormalForm || (production.pattern == start && production.production.isEmpty)
		}) {
			self.productions = productions
			self.start = start
			self.normalizationNonTerminals = []
		} else {
			self = Grammar.makeChomskyNormalForm(of: productions, start: start)
		}
	}
	
	init(productions: [Production], start: NonTerminal, normalizationNonTerminals: Set<NonTerminal>) {
		self.productions = productions
		self.start = start
		self.normalizationNonTerminals = normalizationNonTerminals
	}
	
	public func contains(_ word: String) -> Bool {
		return (try? syntaxTree(for: word)) != nil
	}
	
	public func tokenize(_ word: String) throws -> [[SyntaxTree<Production, Range<String.Index>>]] {
		let finalProductions = productions.filter(\.isFinal).filter{!$0.production.isEmpty}
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
	
	private func generateError(_ cykTable: Array<[[SyntaxTree<Production, Range<String.Index>>]]>) -> SyntaxError {
		let memberRows = (0..<cykTable.count).map { columnIndex -> Int? in
			(0 ..< (cykTable.count - columnIndex)).reduce(nil) { maxIndex, rowIndex -> Int? in
				if cykTable[rowIndex][columnIndex].contains(where: { tree -> Bool in
					tree.root?.pattern == start
				}) {
					return rowIndex
				}
				return maxIndex
			}
		}
		
		if let firstMember = memberRows[0] {
			return SyntaxError.unmatchedPattern(pattern: unfoldChainProductions(cykTable[0][firstMember+1][0]))
		} else {
			return SyntaxError.unmatchedPattern(pattern: unfoldChainProductions(cykTable[0][0][0]))
		}
	}
	
	private func unfoldChainProductions(_ tree: SyntaxTree<Production, Range<String.Index>>) -> SyntaxTree<NonTerminal, Range<String.Index>> {
		switch tree {
		case .leaf(let leaf):
			return .leaf(leaf)
			
		case .node(key: let production, children: let children):
			guard let chain = production.nonTerminalChain else {
				return .node(key: production.pattern, children: children.map(unfoldChainProductions))
			}
			let newNode = chain.reversed().reduce(children.map(unfoldChainProductions)) { (childNodes, nonTerminal) -> [SyntaxTree<NonTerminal, Range<String.Index>>] in
				[SyntaxTree.node(key: nonTerminal, children: childNodes)]
			}
			return .node(key: production.pattern, children: newNode)
		}
	}
	
	public func syntaxTree(`for` word: String) throws -> SyntaxTree<NonTerminal, Range<String.Index>> {
		let finalProductions = productions.filter(\.isFinal).filter{!$0.production.isEmpty}
		
		// Tokenizes a word based on the production rules
		let tokenization = try tokenize(word: word, from: word.startIndex, finalProductions: finalProductions)
		
		return try syntaxTree(for: tokenization)
	}
	
	public func syntaxTree(for tokenization: [[SyntaxTree<Production, Range<String.Index>>]]) throws -> SyntaxTree<NonTerminal, Range<String.Index>> {
		if tokenization.isEmpty {
			if productions.contains(where: { production -> Bool in
				production.pattern == start && production.generatedTerminals.isEmpty
			}) {
				return SyntaxTree.node(key: start, children: [SyntaxTree.leaf("".startIndex ..< "".endIndex)])
			} else {
				throw SyntaxError.emptyWordNotAllowed
			}
		}
		
		let nonTerminalProductions = Dictionary(grouping: productions.filter{!$0.isFinal}) { production -> NonTerminalString in
			NonTerminalString(characters: production.generatedNonTerminals)
		}
		
		var cykTable = [[[SyntaxTree<Production, Range<String.Index>>]]](repeating: [], count: tokenization.count)
		cykTable[0] = tokenization
		
		for row in 1 ..< cykTable.count {
			let upperBound = cykTable.count - row
			
			cykTable[row] = (0..<upperBound).map { column -> [SyntaxTree<Production, Range<String.Index>>] in
				(1...row).flatMap { offset -> [SyntaxTree<Production, Range<String.Index>>] in
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
					}.unique(by: {$0.root!.pattern}).collect(Array.init)
			}
		}
		
		//		print(cykTable.map { row -> String in
		//			row.map { entry -> String in
		//				"[\(entry.map(\.description).joined(separator: ", "))]"
		//			}.joined(separator: ", ")
		//		}.joined(separator: "\n"))
		
		// If a given word is not a member of the language generated by this grammar
		// an error will be computed that returns the first and largest structure
		// in the syntax tree that the parser was unable to process.
		guard let syntaxTree = cykTable[cykTable.count-1][0].first(where: { tree -> Bool in
			tree.root?.pattern == start
		}) else {
			throw generateError(cykTable)
		}
		return unfoldChainProductions(syntaxTree).explode(normalizationNonTerminals.contains)[0]
	}
}


extension Grammar: CustomStringConvertible {
	public var description: String {
		let groupedProductions = Dictionary(grouping: self.productions) { production in
			production.pattern
		}
		return groupedProductions.sorted(by: {$0.key.name < $1.key.name}).map { entry -> String in
			let (pattern, productions) = entry
			
			let productionString = productions.map { production in
				production.production.map(\.description).joined(separator: " ")
			}.joined(separator: " | ")
			
			return "\(pattern.name) --> \(productionString)"
		}.joined(separator: "\n")
	}
}

