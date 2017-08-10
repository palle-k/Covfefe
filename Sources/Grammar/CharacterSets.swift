//
//  CharacterSets.swift
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

public struct SymbolSet {
	public static let whitespace = ProductionResult(SymbolSet(" \t\n".map(String.init).map(t)))
	public static let lowercase = ProductionResult(SymbolSet("abcdefghijklmnopqrstuvwxyz".map(String.init).map(t)))
	public static let uppercase = ProductionResult(SymbolSet("ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init).map(t)))
	public static let numbers = ProductionResult(SymbolSet((0...9).map(String.init).map(t)))
	
	public static var letters: ProductionResult {
		return lowercase <|> uppercase
	}
	
	public static var alphanumerics: ProductionResult {
		return letters <|> numbers
	}
	
	public let symbols: [Symbol]
	
	public init<S: Sequence>(_ sequence: S) where S.Element == Symbol {
		self.symbols = Array(sequence)
	}
}

public func + (lhs: [[Symbol]], rhs: Symbol) -> [[Symbol]] {
	return lhs.map {$0 + [rhs]}
}

public func + (lhs: Symbol, rhs: [[Symbol]]) -> [[Symbol]] {
	return rhs.map {[lhs] + $0}
}

public struct ProductionString {
	public var characters: [Symbol]
	
	public init(_ characters: [Symbol]) {
		self.characters = characters
	}
}

public struct NonTerminalString {
	public var characters: [NonTerminal]
}

extension NonTerminalString: Hashable {
	public var hashValue: Int {
		return characters.enumerated().reduce(0, { partialHash, element in
			return partialHash ^ ((element.element.hashValue >> (element.offset % 64)) | (element.element.hashValue << (64 - (element.offset % 64))))
		})
	}
	
	public static func ==(lhs: NonTerminalString, rhs: NonTerminalString) -> Bool {
		return lhs.characters == rhs.characters
	}
}

extension ProductionString: ExpressibleByArrayLiteral {
	public typealias ArrayLiteralElement = Symbol
	
	public init(arrayLiteral elements: Symbol...) {
		self.init(elements)
	}
}

public struct ProductionResult {
	public var elements: [ProductionString]
	
	public init(symbols: [ProductionString]) {
		self.elements = symbols
	}
}

extension ProductionResult: ExpressibleByArrayLiteral {
	public typealias ArrayLiteralElement = ProductionString
	
	public init(arrayLiteral elements: ProductionString...) {
		self.init(symbols: elements)
	}
}

public extension ProductionResult {
	public init(_ set: SymbolSet) {
		self.elements = set.symbols.map{ProductionString([$0])}
	}
}

precedencegroup ConcatenationPrecendence {
	associativity: left
	higherThan: AlternativePrecedence
	lowerThan: AdditionPrecedence
}

precedencegroup AlternativePrecedence {
	associativity: left
	higherThan: ProductionPrecedence
}

infix operator <+> : ConcatenationPrecendence
infix operator <|> : AlternativePrecedence

public func <+> (lhs: ProductionString, rhs: ProductionString) -> ProductionString {
	return ProductionString(lhs.characters + rhs.characters)
}

public func <+> (lhs: ProductionString, rhs: Symbol) -> ProductionString {
	return ProductionString(lhs.characters + [rhs])
}

public func <+> (lhs: Symbol, rhs: ProductionString) -> ProductionString {
	return ProductionString([lhs] + rhs.characters)
}

public func <+> (lhs: Symbol, rhs: Symbol) -> ProductionString {
	return ProductionString([lhs, rhs])
}

public func <+> (lhs: ProductionResult, rhs: ProductionResult) -> ProductionResult {
	return ProductionResult(symbols: crossProduct(lhs.elements, rhs.elements).map(<+>))
}

public func <+> (lhs: ProductionResult, rhs: ProductionString) -> ProductionResult {
	return ProductionResult(symbols: lhs.elements.map{$0 <+> rhs})
}

public func <+> (lhs: ProductionString, rhs: ProductionResult) -> ProductionResult {
	return ProductionResult(symbols: rhs.elements.map{lhs <+> $0})
}

public func <|> (lhs: ProductionResult, rhs: ProductionResult) -> ProductionResult {
	return ProductionResult(symbols: lhs.elements + rhs.elements)
}

public func <|> (lhs: ProductionResult, rhs: ProductionString) -> ProductionResult {
	return ProductionResult(symbols: lhs.elements + [rhs])
}

public func <|> (lhs: ProductionString, rhs: ProductionResult) -> ProductionResult {
	return ProductionResult(symbols: [lhs] + rhs.elements)
}

public func <|> (lhs: ProductionString, rhs: ProductionString) -> ProductionResult {
	return ProductionResult(symbols: [lhs, rhs])
}

public func <|> (lhs: ProductionString, rhs: Symbol) -> ProductionResult {
	return ProductionResult(symbols: [lhs, [rhs]])
}

public func <|> (lhs: Symbol, rhs: ProductionString) -> ProductionResult {
	return ProductionResult(symbols: [[lhs], rhs])
}

public func <|> (lhs: ProductionResult, rhs: Symbol) -> ProductionResult {
	return ProductionResult(symbols: lhs.elements + [[rhs]])
}

public func <|> (lhs: Symbol, rhs: ProductionResult) -> ProductionResult {
	return ProductionResult(symbols: [[lhs]] + rhs.elements)
}

public func <|> (lhs: Symbol, rhs: Symbol) -> ProductionResult {
	return ProductionResult(symbols: [[lhs], [rhs]])
}
