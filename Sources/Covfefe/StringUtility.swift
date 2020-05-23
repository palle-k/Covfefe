//
//  StringUtility.swift
//  Covfefe
//
//  Created by Palle Klewitz on 19.09.17.
//  Copyright (c) 2017 - 2020 Palle Klewitz
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

public extension String {
	
	/// Returns the ranges of all matches of a regular expression which is provided as the pattern argument
	///
	/// - Parameter pattern: Regular expression for which matches should be searched
	/// - Returns: Ranges of matches in the string for the given regular expression
	/// - Throws: An error indicating that the provided regular expression is invalid.
	func matches(for pattern: String) throws -> [Range<String.Index>] {
		return try matches(for: pattern, in: startIndex ..< endIndex)
	}
	
	/// Returns the ranges of all matches of the provided regular expression
	///
	/// - Parameter expression: Regular expression for which matches should be searched
	/// - Returns: Ranges of matches in the string for the given regular expression
	func matches(for expression: NSRegularExpression) -> [Range<String.Index>] {
		return matches(for: expression, in: startIndex ..< endIndex)
	}

	/// Returns the ranges of all matches of a regular expression which is provided as the pattern argument
	///
	/// - Parameters:
	///   - pattern: Regular expression for which matches should be searched
	///   - range: Range of the string which should be checked
	/// - Returns: Ranges of matches in the string for the given regular expression
	/// - Throws: An error indicating that the provided regular expression is invalid.
	func matches(for pattern: String, in range: Range<String.Index>) throws -> [Range<String.Index>] {
		let expression = try NSRegularExpression(pattern: pattern, options: [])
		return matches(for: expression, in: range)
	}
	
	/// Returns the ranges of all matches of the provided regular expression
	///
	/// - Parameters:
	///   - expression: Regular expression for which matches should be searched
	///   - range: Range of the string which should be checked
	/// - Returns: Ranges of matches in the string for the given regular expression
	func matches(for expression: NSRegularExpression, in range: Range<String.Index>) -> [Range<String.Index>] {
		let range = NSRange(range, in: self)
		let matches = expression.matches(in: self, options: [], range: range)
		return matches.compactMap { match -> Range<String.Index>? in
			return Range(match.range, in: self)
		}
	}
	
	/// Returns a boolean value indicating that the string has a prefix which can be matched by the given regular expression
	///
	/// - Parameter pattern: Regular expression
	/// - Returns: True, if the regular expression matches a substring beginning at the start index of the string
	/// - Throws: An error indicating that the provided regular expression is invalid
	func hasRegularPrefix(_ pattern: String) throws -> Bool {
		return try hasRegularPrefix(pattern, from: self.startIndex)
	}
	
	/// Returns a boolean value indicating that the string has a prefix which can be matched by the given regular expression
	///
	/// - Parameter pattern: Regular expression
	/// - Returns: True, if the regular expression matches a substring beginning at the start index of the string
	func hasRegularPrefix(_ expression: NSRegularExpression) -> Bool {
		return hasRegularPrefix(expression, from: self.startIndex)
	}
	
	/// Returns a boolean value indicating that the string has a prefix beginning at the given start index
	/// which can be matched by the given regular expression
	///
	/// - Parameter pattern: Regular expression
	/// - Parameter startIndex: Start index for the search
	/// - Returns: True, if the regular expression matches a substring beginning at the start index of the string
	/// - Throws: An error indicating that the provided regular expression is invalid
	func hasRegularPrefix(_ pattern: String, from startIndex: String.Index) throws -> Bool {
		return try rangeOfRegularPrefix(pattern, from: startIndex) != nil
	}
	
	/// Returns a boolean value indicating that the string has a prefix beginning at the given start index
	/// which can be matched by the given regular expression
	///
	/// - Parameter pattern: Regular expression
	/// - Parameter startIndex: Start index for the search
	/// - Returns: True, if the regular expression matches a substring beginning at the start index of the string
	/// - Throws: An error indicating that the provided regular expression is invalid
	func hasRegularPrefix(_ expression: NSRegularExpression, from startIndex: String.Index) -> Bool {
		return rangeOfRegularPrefix(expression, from: startIndex) != nil
	}
	
	/// Returns the range of a match for the given regular expression beginning at the start of the string
	///
	/// - Parameter pattern: Regular expression
	/// - Returns: Range of the prefix matched by the regular expression or nil, if no match was found
	/// - Throws: An error indicating that the provided regular expression is invalid
	func rangeOfRegularPrefix(_ pattern: String) throws -> Range<String.Index>? {
		return try rangeOfRegularPrefix(pattern, from: self.startIndex)
	}
	
	/// Returns the range of a match for the given regular expression beginning at the start of the string
	///
	/// - Parameter pattern: Regular expression
	/// - Returns: Range of the prefix matched by the regular expression or nil, if no match was found
	/// - Throws: An error indicating that the provided regular expression is invalid
	func rangeOfRegularPrefix(_ expression: NSRegularExpression) -> Range<String.Index>? {
		return rangeOfRegularPrefix(expression, from: self.startIndex)
	}
	
	/// Returns the range of a match for the given regular expression beginning at the start of the string
	///
	/// - Parameter pattern: Regular expression
	/// - Parameter startIndex: Start index for the search
	/// - Returns: Range of the prefix matched by the regular expression or nil, if no match was found
	/// - Throws: An error indicating that the provided regular expression is invalid
	func rangeOfRegularPrefix(_ pattern: String, from lowerBound: String.Index) throws -> Range<String.Index>? {
		let expression = try NSRegularExpression(pattern: pattern, options: [])
		return rangeOfRegularPrefix(expression, from: lowerBound)
	}
	
	/// Returns the range of a match for the given regular expression beginning at the start of the string
	///
	/// - Parameter pattern: Regular expression
	/// - Parameter startIndex: Start index for the search
	/// - Returns: Range of the prefix matched by the regular expression or nil, if no match was found
	/// - Throws: An error indicating that the provided regular expression is invalid
	func rangeOfRegularPrefix(_ expression: NSRegularExpression, from lowerBound: String.Index) -> Range<String.Index>? {
		let range = NSRange(lowerBound ..< self.endIndex, in: self)
		guard let match = expression.firstMatch(in: self, options: .anchored, range: range) else {
			return nil
		}
		return Range(match.range, in: self)
	}
	
	/// Returns a boolean value indicating that the string ends with a substring matched by the given regular expression
	///
	/// - Parameter pattern: Regular expression
	/// - Returns: True, if a match was found
	/// - Throws: An error indicating that the regular expression is invalid
	func hasRegularSuffix(_ pattern: String) throws -> Bool {
		return try matches(for: pattern).contains(where: { range -> Bool in
			range.upperBound == self.endIndex
		})
	}
	
	/// Returns a boolean value indicating that the string ends with a substring matched by the given regular expression
	///
	/// - Parameter pattern: Regular expression
	/// - Returns: True, if a match was found
	/// - Throws: An error indicating that the regular expression is invalid
	func hasRegularSuffix(_ expression: NSRegularExpression) -> Bool {
		return matches(for: expression).contains(where: { range -> Bool in
			range.upperBound == self.endIndex
		})
	}
	
	/// Returns the range of a substring matched by the given regular expression ending at the end index of the string
	///
	/// - Parameter pattern: Regular expression
	/// - Returns: Range of the match or nil, if no match was found
	/// - Throws: An error indicating that the regular expression is invalid
	func rangeOfRegularSuffix(_ pattern: String) throws -> Range<String.Index>? {
		return try matches(for: pattern).first(where: { range -> Bool in
			range.upperBound == self.endIndex
		})
	}
	
	/// Returns the range of a substring matched by the given regular expression ending at the end index of the string
	///
	/// - Parameter pattern: Regular expression
	/// - Returns: Range of the match or nil, if no match was found
	/// - Throws: An error indicating that the regular expression is invalid
	func rangeOfRegularSuffix(_ expression: NSRegularExpression) throws -> Range<String.Index>? {
		return matches(for: expression).first(where: { range -> Bool in
			range.upperBound == self.endIndex
		})
	}
	
	/// Returns a boolean value indicating that the string has a prefix described by the given terminal symbol.
	///
	/// - Parameter prefix: Sequence of terminal symbols
	/// - Returns: True, if the string has a prefix described by the given non-terminal sequence
	func hasPrefix(_ prefix: Terminal) -> Bool {
		return hasPrefix(prefix, from: self.startIndex)
	}
	
	/// Returns a boolean value indicating that the string has a prefix from the given start index described by the given
	/// terminal symbol
	///
	/// - Parameters:
	///   - prefix: Sequence of terminal symbols
	///   - startIndex: Index from which the search should start
	/// - Returns: True, if the string has a prefix from the given start index described by the given non-terminal sequence
	func hasPrefix(_ prefix: Terminal, from startIndex: String.Index) -> Bool {
		switch prefix {
		case .characterRange(let range, _):
			guard let first = self[startIndex...].first else {
				return false
			}
			return range.contains(first)
			
		case .regularExpression(let expression, _):
			return hasRegularPrefix(expression, from: startIndex)
			
		case .string(string: let string, hash: _):
			return self[startIndex...].hasPrefix(string)
		}
	}
	
	/// Returns the range of the prefix described by the given sequence of terminal symbols
	/// starting a the given start index
	///
	/// - Parameter
	///   - prefix: Sequence of terminal symbols
	///   - startIndex: Index from which the search should start
	/// - Returns: The range of the prefix or nil, if no matching prefix has been found
	func rangeOfPrefix(_ prefix: Terminal, from startIndex: String.Index) -> Range<String.Index>? {
		switch prefix {
		case .characterRange(let range, _):
			guard let first = self[startIndex...].first else {
				return nil
			}
			if range.contains(first) {
				return startIndex ..< self.index(after: startIndex)
			} else {
				return nil
			}
			
		case .regularExpression(let expression, _):
			return rangeOfRegularPrefix(expression, from: startIndex)
			
		case .string(string: let prefixString, hash: _):
			let range = startIndex ..< (self.index(startIndex, offsetBy: prefixString.count, limitedBy: endIndex) ?? endIndex)
			return self.range(of: prefixString, range: range)
		}
	}
		
	/// Performs replacements using the given replacement rules.
	/// The replacements are performed in order.
	/// Each replacement is a tuple of strings, where the first string is the pattern that is replaced
	/// and the second string is the string that is placed.
	///
	/// - Parameter replacements: Sequence of replacements to be performed
	/// - Returns: String generated by performing the sequence of replacements provided
	func replacingOccurrences<Replacements: Sequence>(_ replacements: Replacements) -> String where Replacements.Element == (String, String) {
		return replacements.reduce(self) { acc, rule in
			acc.replacingOccurrences(of: rule.0, with: rule.1)
		}
	}
	
	/// Escapes all special characters that need to be escaped to be escaped for the string to be printed as a string literal.
	/// This includes backslashes, line feeds, carriage returns and tab characters.
	var literalEscaped: String {
		return self.replacingOccurrences(
			[
				("\\", "\\\\"),
				("\n", "\\n"),
				("\r", "\\r"),
				("\t", "\\t"),
			]
		)
	}

	/// Escapes all special characters that need to be escaped to be escaped for the string to be printed as a string literal enclosed by single quotes.
	/// This includes single quotes, backslashes, line feeds, carriage returns and tab characters.
	var singleQuoteLiteralEscaped: String {
		return literalEscaped.replacingOccurrences(of: "'", with: "\\'")
	}
	
	/// Escapes all special characters that need to be escaped to be escaped for the string to be printed as a string literal enclosed by double quotes.
	/// This includes double quotes, backslashes, line feeds, carriage returns and tab characters.
	var doubleQuoteLiteralEscaped: String {
		return literalEscaped.replacingOccurrences(of: "\"", with: "\\\"")
	}
}
