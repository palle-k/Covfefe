//
//  CYKParser.swift
//  Covfefe
//
//  Created by Palle Klewitz on 15.08.17.
//

import Foundation

public class CYKParser {
	public let grammar: Grammar
	private lazy var normalizedGrammar: Grammar = grammar.chomskyNormalized()
	
	public init(grammar: Grammar) {
		self.grammar = grammar
	}
	
	public func recognizes(_ word: String) -> Bool {
		return (try? syntaxTree(for: word)) != nil
	}
	
	public func tokenize(_ word: String) throws -> [[SyntaxTree<Production, Range<String.Index>>]] {
		let finalProductions = normalizedGrammar.productions.filter(\.isFinal).filter{!$0.production.isEmpty}
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
					tree.root?.pattern == normalizedGrammar.start
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
		let finalProductions = normalizedGrammar.productions.filter(\.isFinal).filter{!$0.production.isEmpty}
		
		// Tokenizes a word based on the production rules
		let tokenization = try tokenize(word: word, from: word.startIndex, finalProductions: finalProductions)
		
		return try syntaxTree(for: tokenization)
	}
	
	public func syntaxTree(for tokenization: [[SyntaxTree<Production, Range<String.Index>>]]) throws -> SyntaxTree<NonTerminal, Range<String.Index>> {
		if tokenization.isEmpty {
			if normalizedGrammar.productions.contains(where: { production -> Bool in
				production.pattern == normalizedGrammar.start && production.generatedTerminals.isEmpty
			}) {
				return SyntaxTree.node(key: normalizedGrammar.start, children: [SyntaxTree.leaf("".startIndex ..< "".endIndex)])
			} else {
				throw SyntaxError.emptyWordNotAllowed
			}
		}
		
		let nonTerminalProductions = Dictionary(grouping: normalizedGrammar.productions.filter{!$0.isFinal}) { production -> NonTerminalString in
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
		
		// If a given word is not a member of the language generated by this grammar
		// an error will be computed that returns the first and largest structure
		// in the syntax tree that the parser was unable to process.
		guard let syntaxTree = cykTable[cykTable.count-1][0].first(where: { tree -> Bool in
			tree.root?.pattern == normalizedGrammar.start
		}) else {
			throw generateError(cykTable)
		}
		return unfoldChainProductions(syntaxTree).explode(normalizedGrammar.normalizationNonTerminals.contains)[0]
	}
}
