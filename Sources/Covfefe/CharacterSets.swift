//
//  CharacterSets.swift
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

public func t() -> ProductionString {
	return []
}

/// A string of symbols which can be used in a production of a grammar
public struct ProductionString {
	
	/// Symbols of this production string
	public var characters: [Symbol]
	
	/// Creates a new production string
	///
	/// - Parameter characters: Symbols of the production string
	public init(_ characters: [Symbol]) {
		self.characters = characters
	}
}

/// A string of non-terminal symbols
public struct NonTerminalString {
	
	/// The non-terminal characters of this string
	public var characters: [NonTerminal]
}

extension NonTerminalString: Hashable {
	public var hashValue: Int {
		return characters.enumerated().reduce(0, { partialHash, element in
			return partialHash ^ ((element.element.hashValue >> (element.offset % 64)) | (element.element.hashValue << (64 - (element.offset % 64))))
		})
	}
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(hashValue)
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

/// A production result contains multiple possible production strings
/// which can all be generated from a given non-terminal.
///
/// A production result can be used when creating a production rule with different possible productions:
///
///		"A" --> n("B") <|> t("x")
/// 				 	^ generates a production result
public struct ProductionResult {
	
	/// The possible production strings of this result
	public var elements: [ProductionString]
	
	
	/// Creates a new production result.
	///
	/// - Parameter symbols: Possible strings which can be produced
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

/// Concatenates two production strings
///
/// - Parameters:
///   - lhs: First production string
///   - rhs: Second production string
/// - Returns: Concatenation of the given production strings
public func <+> (lhs: ProductionString, rhs: ProductionString) -> ProductionString {
	return ProductionString(lhs.characters + rhs.characters)
}

/// Concatenates a production string and a symbol
///
/// - Parameters:
///   - lhs: A production string
///   - rhs: A symbol
/// - Returns: Concatenation of the production string and symbol
public func <+> (lhs: ProductionString, rhs: Symbol) -> ProductionString {
	return ProductionString(lhs.characters + [rhs])
}

/// Concatenates a production string and a symbol
///
/// - Parameters:
///   - lhs: A symbol
///   - rhs: A production string
/// - Returns: Concatenation of the production string and symbol
public func <+> (lhs: Symbol, rhs: ProductionString) -> ProductionString {
	return ProductionString([lhs] + rhs.characters)
}

/// Concatenates two production symbols into a production string
///
/// - Parameters:
///   - lhs: First symbol
///   - rhs: Second symbol
/// - Returns: Concatenation of the given symbols
public func <+> (lhs: Symbol, rhs: Symbol) -> ProductionString {
	return ProductionString([lhs, rhs])
}

/// Concatenates every possible production of the first production result with
/// every possible production of the second production result
///
/// - Parameters:
///   - lhs: First production result
///   - rhs: Second production result
/// - Returns: Every possible concatenation of the production strings in the given production results
public func <+> (lhs: ProductionResult, rhs: ProductionResult) -> ProductionResult {
	return ProductionResult(symbols: crossProduct(lhs.elements, rhs.elements).map(<+>))
}

/// Concatenates every production string of the production result with the given production string
///
/// - Parameters:
///   - lhs: Production result
///   - rhs: Production string
/// - Returns: Concatenation of every production string in the production result with the given production string
public func <+> (lhs: ProductionResult, rhs: ProductionString) -> ProductionResult {
	return ProductionResult(symbols: lhs.elements.map{$0 <+> rhs})
}

/// Concatenates the given production string with every production string of the production result
///
/// - Parameters:
///   - lhs: Production string
///   - rhs: Production result
/// - Returns: Concatenation of the given production string with every production string in the production result
public func <+> (lhs: ProductionString, rhs: ProductionResult) -> ProductionResult {
	return ProductionResult(symbols: rhs.elements.map{lhs <+> $0})
}

/// Generates a production result containing every production string of the given production results
///
/// - Parameters:
///   - lhs: First production result
///   - rhs: Second production result
/// - Returns: Joined production result of the given production results
public func <|> (lhs: ProductionResult, rhs: ProductionResult) -> ProductionResult {
	return ProductionResult(symbols: lhs.elements + rhs.elements)
}

/// Generates a production result containing every production of the left production result and the production string
///
/// - Parameters:
///   - lhs: Production result
///   - rhs: Production string
/// - Returns: A production result generated by merging the left production result with the right production string
public func <|> (lhs: ProductionResult, rhs: ProductionString) -> ProductionResult {
	return ProductionResult(symbols: lhs.elements + [rhs])
}

/// Generates a production result containing the left production string and every production of the right production string
///
/// - Parameters:
///   - lhs: Production string
///   - rhs: Production result
/// - Returns: A production result generated by merging the left production string with the right production result
public func <|> (lhs: ProductionString, rhs: ProductionResult) -> ProductionResult {
	return ProductionResult(symbols: [lhs] + rhs.elements)
}

/// Generates a production result containing the left and right production string
///
/// - Parameters:
///   - lhs: First production string
///   - rhs: Second production string
/// - Returns: A production result containing the left and right production string
public func <|> (lhs: ProductionString, rhs: ProductionString) -> ProductionResult {
	return ProductionResult(symbols: [lhs, rhs])
}

/// Generates a production result containing the left production string and the right symbol
///
/// - Parameters:
///   - lhs: Production string
///   - rhs: Symbol
/// - Returns: A production result allowing the left production string and the right symbol
public func <|> (lhs: ProductionString, rhs: Symbol) -> ProductionResult {
	return ProductionResult(symbols: [lhs, [rhs]])
}

/// Generates a production result containing the left symbol and the right production string
///
/// - Parameters:
///   - lhs: Symbol
///   - rhs: Production string
/// - Returns: A production result allowing the left symbol and the right production string
public func <|> (lhs: Symbol, rhs: ProductionString) -> ProductionResult {
	return ProductionResult(symbols: [[lhs], rhs])
}

/// Generates a production result by appending the right symbol to the left production result
///
/// - Parameters:
///   - lhs: Production result
///   - rhs: Symbol
/// - Returns: A production result allowing every production string of the left production result and the right symbol
public func <|> (lhs: ProductionResult, rhs: Symbol) -> ProductionResult {
	return ProductionResult(symbols: lhs.elements + [[rhs]])
}

/// Generates a production result by appending the left symbol to the right production result
///
/// - Parameters:
///   - lhs: Symbol
///   - rhs: Production result
/// - Returns: A production result allowing the left symbol and every production string of the right production result
public func <|> (lhs: Symbol, rhs: ProductionResult) -> ProductionResult {
	return ProductionResult(symbols: [[lhs]] + rhs.elements)
}

/// Generates a production result containing the left and right symbol
///
/// - Parameters:
///   - lhs: Left symbol
///   - rhs: Right symbol
/// - Returns: A production result allowing either the left or the right symbol
public func <|> (lhs: Symbol, rhs: Symbol) -> ProductionResult {
	return ProductionResult(symbols: [[lhs], [rhs]])
}
