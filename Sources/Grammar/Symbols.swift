//
//  Symbols.swift
//  Grammar
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

public struct NonTerminal {
	public let name: String
	
	public init(name: String) {
		self.name = name
	}
}

extension NonTerminal: CustomStringConvertible {
	public var description: String {
		return name
	}
}

extension NonTerminal: ExpressibleByStringLiteral {
	public typealias StringLiteralType = String
	
	public init(stringLiteral value: String) {
		self.init(name: value)
	}
}

extension NonTerminal: Hashable {
	public var hashValue: Int {
		return name.hashValue
	}
	
	public static func ==(lhs: NonTerminal, rhs: NonTerminal) -> Bool {
		return lhs.name == rhs.name
	}
}

public struct Terminal {
	public let value: String
	public let isRegularExpression: Bool
	
	public init(value: String, isRegularExpression: Bool = false) throws {
		self.value = value
		self.isRegularExpression = isRegularExpression
		
		if isRegularExpression {
			_ = try NSRegularExpression(pattern: value, options: [])
		}
	}
}

extension Terminal: ExpressibleByStringLiteral {
	public typealias StringLiteralType = String
	
	public init(stringLiteral value: String) {
		try! self.init(value: value)
	}
}

extension Terminal: Hashable {
	public var hashValue: Int {
		return value.hashValue
	}
	
	public static func ==(lhs: Terminal, rhs: Terminal) -> Bool {
		return lhs.value == rhs.value
	}
}

extension Terminal: CustomStringConvertible {
	public var description: String {
		return value
	}
}

public enum Symbol {
	case terminal(Terminal)
	case nonTerminal(NonTerminal)
}

public func t(_ value: String) -> Symbol {
	return try! Symbol.terminal(Terminal(value: value))
}

public func n(_ name: String) -> Symbol {
	return Symbol.nonTerminal(NonTerminal(name: name))
}

public func rt(_ value: String) throws -> Symbol {
	return try Symbol.terminal(Terminal(value: value, isRegularExpression: true))
}

extension Symbol: Hashable {
	public var hashValue: Int {
		switch self {
		case .terminal(let t):
			return t.hashValue
			
		case .nonTerminal(let n):
			return n.hashValue
		}
	}
	
	public static func == (lhs: Symbol, rhs: Symbol) -> Bool {
		switch (lhs, rhs) {
		case (.terminal(let l), .terminal(let r)):
			return l == r
			
		case (.nonTerminal(let l), .nonTerminal(let r)):
			return l == r
			
		default:
			return false
		}
	}
}

extension Symbol: CustomStringConvertible {
	public var description: String {
		switch self {
		case .nonTerminal(let n):
			return n.name
			
		case .terminal(let t):
			return t.value
		}
	}
}
