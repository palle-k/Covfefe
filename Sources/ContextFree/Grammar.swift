//
//  Grammar.swift
//  ContextFree
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

enum SyntaxError: Error {
	case unknownSequence(from: String)
	case unmatchedPattern(pattern: Tree<NonTerminal, Range<String.Index>>)
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
	
	public func contains(word: String) -> Bool {
		return (try? generateSyntaxTree(for: word)) != nil
	}
	
	public func generateSyntaxTree(`for` word: String) throws -> Tree<NonTerminal, Range<String.Index>> {
		let finalProductions = productions.filter(\.isFinal)
		
		// Tokenizes a word based on the production rules
		func tokenize(word: String, from startIndex: String.Index) throws -> [[Tree<NonTerminal, Range<String.Index>>]] {
			if word[startIndex...].isEmpty {
				return []
			}
			let matches = finalProductions.filter { production -> Bool in
				word.hasPrefix(production.generatedTerminals, from: startIndex)
			}
			guard let first = matches.first, let firstMatchRange = word.rangeOfPrefix(first.generatedTerminals, from: startIndex) else {
				throw SyntaxError.unknownSequence(from: String(word[startIndex...]))
			}
			
			//let firstMatchString = String(word[firstMatchRange])
			
			//TODO: Do not cut string, just instruct subsequent calls to only search after match range
			// This would also improve performance
//			let rest = { () -> String in
//				var rest = word
//				rest.removeSubrange(firstMatchRange)
//				return rest
//			}()
			
			let restTokenization = try tokenize(word: word, from: firstMatchRange.upperBound)
			let matchTrees = matches.flatMap { production -> Tree<NonTerminal, Range<String.Index>>? in
				Tree(key: production.pattern, children: [Tree(value: firstMatchRange)])
			}
			//TODO: Make this method tail recursive
			return [matchTrees] + restTokenization
		}
		
		let tokenization = try tokenize(word: word, from: word.startIndex)
		let nonTerminalProductions = Dictionary(grouping: productions.filter{!$0.isFinal}) { production -> NonTerminalString in
			NonTerminalString(characters: production.generatedNonTerminals)
		}
		
		if tokenization.isEmpty {
			if productions.contains(where: { production -> Bool in
				production.pattern == start && production.generatedTerminals.isEmpty
			}) {
				return Tree.node(key: start, children: [Tree.leaf(word.startIndex..<word.endIndex)])
			} else {
				throw SyntaxError.emptyWordNotAllowed
			}
		}
		
		// CYK-Algorithm
		
		var cykTable = Array<[[Tree<NonTerminal, Range<String.Index>>]]>(repeating: [], count: tokenization.count)
		cykTable[0] = tokenization
		
		for row in 1 ..< cykTable.count {
			let upperBound = cykTable.count - row
			
			cykTable[row] = (0..<upperBound).map { column -> [Tree<NonTerminal, Range<String.Index>>] in
				(1...row).flatMap { offset -> [Tree<NonTerminal, Range<String.Index>>] in
					let ref1Row = row - offset
					let ref2Col = column + row - offset + 1
					let ref2Row = offset - 1
					
					return crossProduct(cykTable[ref1Row][column], cykTable[ref2Row][ref2Col]).flatMap { nonTerminals -> [Tree<NonTerminal, Range<String.Index>>] in
						let (leftNonTerminal, rightNonTerminal) = nonTerminals
						let combinedString = NonTerminalString(characters: [leftNonTerminal.root!, rightNonTerminal.root!])
						let possibleProductions = nonTerminalProductions[combinedString, default: []].map(\Production.pattern)
						return possibleProductions.map { pattern -> Tree<NonTerminal, Range<String.Index>> in
							Tree(key: pattern, children: [leftNonTerminal, rightNonTerminal])
						}
					}
				}
			}
		}
		
		// If a given word is not a member of the language generated by this grammar
		// an error will be computed that returns the first and largest structure
		// in the syntax tree that the parser was unable to process.
		
		guard let syntaxTree = cykTable[cykTable.count-1][0].first(where: { tree -> Bool in
			tree.root == start
		}) else {
			let memberRows = (0..<cykTable.count).map { columnIndex -> Int? in
				(0 ..< (cykTable.count - columnIndex)).reduce(nil) { maxIndex, rowIndex -> Int? in
					if cykTable[rowIndex][columnIndex].contains(where: { tree -> Bool in
						tree.root == start
					}) {
						return rowIndex
					}
					return maxIndex
				}
			}
			
			if let firstMember = memberRows[0] {
				throw SyntaxError.unmatchedPattern(pattern: cykTable[0][firstMember+1][0])
			} else {
				throw SyntaxError.unmatchedPattern(pattern: cykTable[0][0][0])
			}
		}
		return syntaxTree.explode(normalizationNonTerminals.contains)[0]
	}
}


extension Grammar: CustomStringConvertible {
	public var description: String {
		let groupedProductions = Dictionary(grouping: self.productions) { production in
			production.pattern
		}
		return groupedProductions.map { entry -> String in
			let (pattern, productions) = entry
			
			let productionString = productions.map { production in
				production.production.map(\.description).joined(separator: " ")
			}.joined(separator: " | ")
			
			return "\(pattern.name) --> \(productionString)"
		}.joined(separator: "\n")
	}
}

