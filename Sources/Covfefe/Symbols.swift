//
//  Symbols.swift
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

/// A non-terminal symbol, which cannot occurr in a word recognized by a parser
public struct NonTerminal: Codable {
	
	/// Name of the non-terminal
	public let name: String
	
	/// Creates a new non-terminal symbol with a given name
	///
	/// - Parameter name: Name of the non-terminal symbol
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

/// A terminal symbol which can occur in a string recognized by a parser and which cannot be
/// replaced by any production
public struct Terminal: Codable {
	
	/// Value of the terminal
	public let value: String
	
	/// Indicates whether the value of the non-terminal is a regular expression
	public let isRegularExpression: Bool
	
	/// Creates a new terminal value which can occurr in a string
	///
	/// **Note**: The value of the terminal string may not overlap partially with any other non-terminal
	/// contained in a grammar. For regular terminals, it it may be deriable to add word boundary markers: `\b`.
	///
	/// - Parameters:
	///   - value: Value of the terminal which can occurr in a string
	///   - isRegularExpression: Indicates whether the value is a regular expression
	/// - Throws: An error if the value is an invalid regular expression
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

/// A symbol which can either be a terminal or a non-terminal character
///
/// - terminal: A terminal character
/// - nonTerminal: A non-terminal character
public enum Symbol: Codable {
	/// A terminal symbol
	case terminal(Terminal)
	
	/// A non-terminal symbol
	case nonTerminal(NonTerminal)
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		if container.allKeys.contains(CodingKeys.terminal) {
			self = try .terminal(container.decode(Terminal.self, forKey: CodingKeys.terminal))
		} else {
			self = try .nonTerminal(container.decode(NonTerminal.self, forKey: CodingKeys.nonTerminal))
		}
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		
		switch self {
		case .terminal(let terminal):
			try container.encode(terminal, forKey: .terminal)
			
		case .nonTerminal(let nonTerminal):
			try container.encode(nonTerminal, forKey: .nonTerminal)
		}
	}
	
	private enum CodingKeys: String, CodingKey {
		case terminal
		case nonTerminal = "non_terminal"
	}
}

/// Creates a new non-regular terminal symbol
///
/// **Note**: The value of the terminal string may not overlap partially with any other non-terminal
/// contained in a grammar.
///
/// - Parameter value: Value of the terminal symbol
/// - Returns: A terminal symbol with the given value
public func t(_ value: String) -> Symbol {
	return try! Symbol.terminal(Terminal(value: value))
}

/// Creates a new non-terminal symbol
///
/// - Parameter name: Name of the non-terminal symbol
/// - Returns: A non-terminal symbol with the given name
public func n(_ name: String) -> Symbol {
	return Symbol.nonTerminal(NonTerminal(name: name))
}

/// Creates a new regular terminal symbol
///
/// **Note**: The value of the terminal string may not overlap partially with any other non-terminal
/// contained in a grammar. For regular terminals, it it may be deriable to add word boundary markers: `\b`.
///
/// - Parameter value: Regular value of the terminal
/// - Returns: A regular terminal symbol
/// - Throws: An error indicating that the given regular expression is invalid
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
