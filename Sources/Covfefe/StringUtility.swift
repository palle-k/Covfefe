//
//  StringUtility.swift
//  Covfefe
//
//  Created by Palle Klewitz on 19.09.17.
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

public extension String {
	
	/// Returns the ranges of all matches of a regular expression which is provided as the pattern argument
	///
	/// - Parameter pattern: Regular expression for which matches should be searched
	/// - Returns: Ranges of matches in the string for the given regular expression
	/// - Throws: An error indicating that the provided regular expression is invalid.
	public func matches(for pattern: String) throws -> [Range<String.Index>] {
		return try matches(for: pattern, in: self.startIndex ..< self.endIndex)
	}

	/// Returns the ranges of all matches of a regular expression which is provided as the pattern argument
	///
	/// - Parameters:
	///   - pattern: Regular expression for which matches should be searched
	///   - range: Range of the string which should be checked
	/// - Returns: Ranges of matches in the string for the given regular expression
	/// - Throws: An error indicating that the provided regular expression is invalid.
	public func matches(for pattern: String, in range: Range<String.Index>) throws -> [Range<String.Index>] {
		let expression = try NSRegularExpression(pattern: pattern, options: [])
		let range = NSRange(range, in: self)
		let matches = expression.matches(in: self, options: [], range: range)
		return matches.flatMap { match -> Range<String.Index>? in
			return Range(match.range, in: self)
		}
	}
	
	/// Returns a boolean value indicating that the string has a prefix which can be matched by the given regular expression
	///
	/// - Parameter pattern: Regular expression
	/// - Returns: True, if the regular expression matches a substring beginning at the start index of the string
	/// - Throws: An error indicating that the provided regular expression is invalid
	public func hasRegularPrefix(_ pattern: String) throws -> Bool {
		return try hasRegularPrefix(pattern, from: self.startIndex)
	}
	
	/// Returns a boolean value indicating that the string has a prefix beginning at the given start index
	/// which can be matched by the given regular expression
	///
	/// - Parameter pattern: Regular expression
	/// - Parameter startIndex: Start index for the search
	/// - Returns: True, if the regular expression matches a substring beginning at the start index of the string
	/// - Throws: An error indicating that the provided regular expression is invalid
	public func hasRegularPrefix(_ pattern: String, from startIndex: String.Index) throws -> Bool {
		return try rangeOfRegularPrefix(pattern, from: startIndex) != nil
	}
	
	/// Returns the range of a match for the given regular expression beginning at the start of the string
	///
	/// - Parameter pattern: Regular expression
	/// - Returns: Range of the prefix matched by the regular expression or nil, if no match was found
	/// - Throws: An error indicating that the provided regular expression is invalid
	public func rangeOfRegularPrefix(_ pattern: String) throws -> Range<String.Index>? {
		return try rangeOfRegularPrefix(pattern, from: self.startIndex)
	}
	
	/// Returns the range of a match for the given regular expression beginning at the start of the string
	///
	/// - Parameter pattern: Regular expression
	/// - Parameter startIndex: Start index for the search
	/// - Returns: Range of the prefix matched by the regular expression or nil, if no match was found
	/// - Throws: An error indicating that the provided regular expression is invalid
	public func rangeOfRegularPrefix(_ pattern: String, from lowerBound: String.Index) throws -> Range<String.Index>? {
		let expression = try NSRegularExpression(pattern: pattern, options: [])
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
	
	/// Returns a boolean value indicating that the string has a prefix described by the given sequence of terminal symbols.
	///
	/// - Parameter prefix: Sequence of terminal symbols
	/// - Returns: True, if the string has a prefix described by the given non-terminal sequence
	func hasPrefix(_ prefix: [Terminal]) -> Bool {
		return hasPrefix(prefix, from: self.startIndex)
	}
	
	/// Returns a boolean value indicating that the string has a prefix from the given start index described by the given
	/// sequence of non-terminal symbols
	///
	/// - Parameters:
	///   - prefix: Sequence of terminal symbols
	///   - startIndex: Index from which the search should start
	/// - Returns: True, if the string has a prefix from the given start index described by the given non-terminal sequence
	func hasPrefix(_ prefix: [Terminal], from startIndex: String.Index) -> Bool {
		let prefixString = prefix.map{$0.value}.joined()
		
		if prefix.contains(where: {$0.isRegularExpression}) {
			return try! self.hasRegularPrefix("\(prefixString)", from: startIndex)
		} else {
			return self[startIndex...].hasPrefix(prefixString)
		}
	}
	
	/// Returns the range of the prefix described by the given sequence of terminal symbols
	///
	/// - Parameter prefix: Sequence of terminal symbols
	/// - Returns: The range of the prefix or nil, if no matching prefix has been found
	func rangeOfPrefix(_ prefix: [Terminal]) -> Range<String.Index>? {
		return rangeOfPrefix(prefix, from: self.startIndex)
	}
	
	/// Returns the range of the prefix described by the given sequence of terminal symbols
	/// starting a the given start index
	///
	/// - Parameter
	///   - prefix: Sequence of terminal symbols
	///   - startIndex: Index from which the search should start
	/// - Returns: The range of the prefix or nil, if no matching prefix has been found
	func rangeOfPrefix(_ prefix: [Terminal], from startIndex: String.Index) -> Range<String.Index>? {
		let prefixString = prefix.map{$0.value}.joined()
		
		if prefix.contains(where: {$0.isRegularExpression}) {
			return try! self.rangeOfRegularPrefix(prefixString, from: startIndex)
		} else {
			let range = startIndex ..< (self.index(startIndex, offsetBy: prefixString.count, limitedBy: endIndex) ?? endIndex)
			return self.range(of: prefixString, range: range)
		}
	}
	
	/// Returns a boolean value indicating that the string has a suffix described by the given sequence of terminal symbols
	///
	/// - Parameter suffix: Sequence of terminal symbols
	/// - Returns: True, if the string has a suffix which matches the suffix described by the given sequence of terminal symbols
	func hasSuffix(_ suffix: [Terminal]) -> Bool {
		let suffixString = suffix.map{$0.value}.joined()
		
		if suffix.contains(where: {$0.isRegularExpression}) {
			return try! self.hasRegularSuffix("\(suffixString)$")
		} else {
			return self.hasSuffix(suffixString)
		}
	}
	
	/// Returns the range of the suffix described by the given sequence of terminal symbols
	///
	/// - Parameter suffix: Sequence of terminal symbols
	/// - Returns: Range of the suffix or nil if no matching suffix was found
	func rangeOfSuffix(_ suffix: [Terminal]) -> Range<String.Index>? {
		let suffixString = suffix.map{$0.value}.joined()
		
		if suffix.contains(where: {$0.isRegularExpression}) {
			return try! self.rangeOfRegularSuffix(suffixString)
		} else {
			return self.range(of: suffixString, options: .backwards)
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
				("\t", "\\t")
			]
		)
	}

	var singleQuoteLiteralEscaped: String {
		return literalEscaped.replacingOccurrences(of: "'", with: "\\'")
	}
	
	var doubleQuoteLiteralEscaped: String {
		return literalEscaped.replacingOccurrences(of: "\"", with: "\\\"")
	}
}
