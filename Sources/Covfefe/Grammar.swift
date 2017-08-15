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
	let normalizationNonTerminals: Set<NonTerminal>
	
	public init(productions: [Production], start: NonTerminal) {
		self.productions = productions
		self.start = start
		self.normalizationNonTerminals = []
	}
	
	init(productions: [Production], start: NonTerminal, normalizationNonTerminals: Set<NonTerminal>) {
		self.productions = productions
		self.start = start
		self.normalizationNonTerminals = normalizationNonTerminals
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
				production.production.map { symbol -> String in
					switch symbol {
					case .nonTerminal(let nonTerminal):
						return "<\(nonTerminal.name)>"
						
					case .terminal(let terminal) where terminal.value.contains("\""):
						return "'\(terminal)'"
					
					case .terminal(let terminal):
						return "\"\(terminal)\""
					}
				}.joined(separator: " ")
			}.joined(separator: " | ")
			
			return "<\(pattern.name)> ::= \(productionString)"
		}.joined(separator: "\n")
	}
}

