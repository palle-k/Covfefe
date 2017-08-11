//
//  Productions.swift
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

public struct Production {
	public let pattern: NonTerminal
	public let production: [Symbol]
	
	let nonTerminalChain: [NonTerminal]?
	
	public init(pattern: NonTerminal, production: ProductionString) {
		self.pattern = pattern
		self.production = production.characters
		self.nonTerminalChain = nil
	}
	
	init(pattern: NonTerminal, production: [Symbol], chain: [NonTerminal]? = nil) {
		self.pattern = pattern
		self.production = production
		self.nonTerminalChain = chain
	}
	
	public var isLinear: Bool {
		return self.production.filter { symbol -> Bool in
			if case .nonTerminal(_) = symbol {
				return true
			} else {
				return false
			}
			}.count <= 1
	}
	
	public var isRightLinear: Bool {
		guard isLinear else {
			return false
		}
		if let index = self.production.index(where: { symbol -> Bool in
			if case .nonTerminal(_) = symbol {
				return true
			} else {
				return false
			}
		}) {
			return index == self.production.count - 1
		}
		return true
	}
	
	public var isLeftLinear: Bool {
		guard isLinear else {
			return false
		}
		if let index = self.production.index(where: { symbol -> Bool in
			if case .nonTerminal(_) = symbol {
				return true
			} else {
				return false
			}
		}) {
			return index == 0
		}
		return true
	}
	
	public var isFinal: Bool {
		return self.production.allMatch { symbol -> Bool in
			if case .terminal(_) = symbol {
				return true
			} else {
				return false
			}
		}
	}
	
	public var isInChomskyNormalForm: Bool {
		if isFinal {
			return production.count == 1
		}
		return self.production.allMatch { symbol -> Bool in
			if case .nonTerminal(_) = symbol {
				return true
			} else {
				return false
			}
		} && self.production.count == 2
	}
	
	var generatedString: String {
		return generatedTerminals.map(\.value).joined()
	}
	
	public var generatedTerminals: [Terminal] {
		return production.flatMap{ symbol -> Terminal? in
			guard case .terminal(let terminal) = symbol  else {
				return nil
			}
			return terminal
		}
	}
	
	var terminalPrefix: [Terminal] {
		let prefix = production.prefix(while: { symbol -> Bool in
			if case .terminal(_) = symbol {
				return true
			} else {
				return false
			}
		})
		return prefix.flatMap { symbol -> Terminal? in
			guard case .terminal(let terminal) = symbol else {
				return nil
			}
			return terminal
		}
	}
	
	var terminalSuffix: [Terminal] {
		let suffix = production.reversed().prefix(while: { symbol -> Bool in
			if case .terminal(_) = symbol {
				return true
			} else {
				return false
			}
		}).reversed()
		
		return suffix.flatMap { symbol -> Terminal? in
			guard case .terminal(let terminal) = symbol else {
				return nil
			}
			return terminal
		}
	}
	
	var prefixString: String {
		return terminalPrefix.map(\.value).joined()
	}
	
	var suffixString: String {
		return terminalSuffix.map(\.value).joined()
	}
	
	public func canGenerateSubstring(of word: String) -> Bool {
		if isRightLinear {
			return word.hasPrefix(terminalPrefix)
		} else if isLeftLinear {
			return word.hasPrefix(terminalSuffix)
		} else if isLinear {
			return word.hasPrefix(terminalPrefix) && word.hasSuffix(terminalSuffix)
		} else {
			fatalError("Cannot check if non-linear production generates substring.")
		}
	}
	
	public func canFullyGenerate(word: String) -> Bool {
		guard isFinal else {
			return false
		}
		return generatedString == word
	}
	
	public func removingGeneratedSubstring(from word: String) -> String {
		guard canGenerateSubstring(of: word) else {
			return word
		}
		
		if isRightLinear, let range = word.rangeOfPrefix(terminalPrefix) {
			var mutableWord = word
			mutableWord.removeSubrange(range)
			return mutableWord
		} else if isLeftLinear, let range = word.rangeOfSuffix(terminalSuffix) {
			var mutableWord = word
			mutableWord.removeSubrange(range)
			return mutableWord
		} else if isLinear {
			var mutableWord = word
			
			guard let prefixRange = word.rangeOfPrefix(terminalPrefix),
				let suffixRange = word.rangeOfSuffix(terminalSuffix) else {
					return word
			}
			
			mutableWord.removeSubrange(suffixRange)
			mutableWord.removeSubrange(prefixRange)
			return mutableWord
		} else {
			fatalError("Cannot remove generated substring from non-left-linear or -right-linear production.")
		}
	}
	
	var generatedNonTerminals: [NonTerminal] {
		return production.flatMap { symbol -> NonTerminal? in
			guard case .nonTerminal(let nonTerminal) = symbol else {
				return nil
			}
			return nonTerminal
		}
	}
}

extension Production: Hashable {
	public var hashValue: Int {
		return pattern.hashValue ^ production.map(\.hashValue).reduce(0, ^)
	}
	
	public static func ==(lhs: Production, rhs: Production) -> Bool {
		return lhs.pattern == rhs.pattern && lhs.production == rhs.production
	}
}

extension Production: CustomStringConvertible {
	public var description: String {
		return "\(pattern.name) --> \(production.map{$0.description}.joined(separator: " "))"
	}
}

extension Production: CustomDebugStringConvertible {
	public var debugDescription: String {
		return """
		production {
			pattern: \(self.pattern)
			produces: \(self.production.map(\.description))
			chain: \(self.nonTerminalChain?.map(\.description).joined(separator: ", ") ?? "empty")
		}
		"""
	}
}

precedencegroup ProductionPrecedence {
	associativity: left
	lowerThan: AdditionPrecedence
}

infix operator --> : ProductionPrecedence

public func --> (lhs: NonTerminal, rhs: ProductionString) -> Production {
	return Production(pattern: lhs, production: rhs)
}

public func --> (lhs: NonTerminal, rhs: ProductionResult) -> [Production] {
	return rhs.elements.map { producedString in
		return Production(pattern: lhs, production: producedString)
	}
}

public func --> (lhs: NonTerminal, rhs: Symbol) -> Production {
	return Production(pattern: lhs, production: [rhs])
}

