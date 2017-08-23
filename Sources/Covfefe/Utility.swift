//
//  Utility.swift
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

extension Sequence {
	func map<Result>(_ keyPath: KeyPath<Element, Result>) -> [Result] {
		return self.map(keyPath.function)
	}
	
	func filter(_ predicate: KeyPath<Element, Bool>) -> [Element] {
		return self.filter(predicate.function)
	}
	
	func flatMap<Result>(_ keyPath: KeyPath<Element, Result?>) -> [Result] {
		return self.flatMap(keyPath.function)
	}

	func flatMap<Result>(_ keyPath: KeyPath<Element, [Result]>) -> [Result] {
		return self.flatMap(keyPath.function)
	}
	
	func sorted<SortKey: Comparable>(by keyPath: KeyPath<Element, SortKey>) -> [Element] {
		return self.sorted(by: { first, second -> Bool in
			return first[keyPath: keyPath] < second[keyPath: keyPath]
		})
	}
}

extension KeyPath {
	var function: (Root) -> Value {
		return { (element: Root) -> Value in
			return element[keyPath: self]
		}
	}
}

extension Sequence {
	func allMatch(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
		return try !self.contains(where: {try !predicate($0)})
	}
	
	func unique<Property: Hashable>(by property: @escaping (Element) -> Property) -> AnySequence<Element> {
		return sequence(state: (makeIterator(), [])) { (state: inout (Iterator, Set<Property>)) -> Element? in
			while let next = state.0.next() {
				guard !state.1.contains(property(next)) else {
					continue
				}
				state.1.insert(property(next))
				return next
			}
			return nil
		}.collect(AnySequence.init)
	}
}

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
		return try matches(for: pattern).contains(where: { range -> Bool in
			range.lowerBound == startIndex
		})
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
	public func rangeOfRegularPrefix(_ pattern: String, from startIndex: String.Index) throws -> Range<String.Index>? {
		return try matches(for: pattern, in: startIndex ..< self.endIndex).first(where: { range -> Bool in
			range.lowerBound == startIndex
		})
	}
	
	/// Returns a boolean value indicating that the string ends with a substring matched by the given regular expression
	///
	/// - Parameter pattern: Regular expression
	/// - Returns: True, if a match was found
	/// - Throws: An error indicating that the regular expression is invalid
	public func hasRegularSuffix(_ pattern: String) throws -> Bool {
		return try matches(for: pattern).contains(where: { range -> Bool in
			range.upperBound == self.endIndex
		})
	}
	
	/// Returns the range of a substring matched by the given regular expression ending at the end index of the string
	///
	/// - Parameter pattern: Regular expression
	/// - Returns: Range of the match or nil, if no match was found
	/// - Throws: An error indicating that the regular expression is invalid
	public func rangeOfRegularSuffix(_ pattern: String) throws -> Range<String.Index>? {
		return try matches(for: pattern).first(where: { range -> Bool in
			range.upperBound == self.endIndex
		})
	}
	
	/// Returns a boolean value indicating that the string has a prefix described by the given sequence of terminal symbols.
	///
	/// - Parameter prefix: Sequence of terminal symbols
	/// - Returns: True, if the string has a prefix described by the given non-terminal sequence
	public func hasPrefix(_ prefix: [Terminal]) -> Bool {
		return hasPrefix(prefix, from: self.startIndex)
	}
	
	/// Returns a boolean value indicating that the string has a prefix from the given start index described by the given
	/// sequence of non-terminal symbols
	///
	/// - Parameters:
	///   - prefix: Sequence of terminal symbols
	///   - startIndex: Index from which the search should start
	/// - Returns: True, if the string has a prefix from the given start index described by the given non-terminal sequence
	public func hasPrefix(_ prefix: [Terminal], from startIndex: String.Index) -> Bool {
		let prefixString = prefix.map(\Terminal.value).joined()
		
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
	public func rangeOfPrefix(_ prefix: [Terminal]) -> Range<String.Index>? {
		return rangeOfPrefix(prefix, from: self.startIndex)
	}
	
	/// Returns the range of the prefix described by the given sequence of terminal symbols
	/// starting a the given start index
	///
	/// - Parameter
	///   - prefix: Sequence of terminal symbols
	///   - startIndex: Index from which the search should start
	/// - Returns: The range of the prefix or nil, if no matching prefix has been found
	public func rangeOfPrefix(_ prefix: [Terminal], from startIndex: String.Index) -> Range<String.Index>? {
		let prefixString = prefix.map(\Terminal.value).joined()
		
		if prefix.contains(where: {$0.isRegularExpression}) {
			return try! self.rangeOfRegularPrefix(prefixString, from: startIndex)
		} else {
			return self.range(of: prefixString, range: startIndex ..< self.endIndex)
		}
	}
	
	/// Returns a boolean value indicating that the string has a suffix described by the given sequence of terminal symbols
	///
	/// - Parameter suffix: Sequence of terminal symbols
	/// - Returns: True, if the string has a suffix which matches the suffix described by the given sequence of terminal symbols
	public func hasSuffix(_ suffix: [Terminal]) -> Bool {
		let suffixString = suffix.map(\Terminal.value).joined()
		
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
	public func rangeOfSuffix(_ suffix: [Terminal]) -> Range<String.Index>? {
		let suffixString = suffix.map(\Terminal.value).joined()
		
		if suffix.contains(where: {$0.isRegularExpression}) {
			return try! self.rangeOfRegularSuffix(suffixString)
		} else {
			return self.range(of: suffixString, options: .backwards)
		}
	}
}

extension IteratorProtocol {
	mutating func skip(_ count: Int) {
		for _ in 0 ..< count {
			_ = self.next()
		}
	}
	
	func peek() -> Element? {
		var iterator = self
		return iterator.next()
	}
}

extension Sequence {
	func strided(_ stride: Int, start: Int? = nil) -> AnySequence<Element> {
		var iterator = self.makeIterator()
		iterator.skip(start ?? 0)
		return sequence(state: iterator) { (iterator: inout Iterator) -> Element? in
			let next = iterator.next()
			iterator.skip(stride - 1)
			return next
			}.collect(AnySequence.init)
	}
	
	func collect<Result>(_ collector: (Self) -> Result) -> Result {
		return collector(self)
	}
	
	func pairs() -> AnySequence<(Element, Element)> {
		return sequence(state: self.makeIterator()) { (iterator: inout Iterator) -> (Element, Element)? in
			guard let first = iterator.next(), let second = iterator.peek() else {
				return nil
			}
			return (first, second)
		}.collect(AnySequence.init)
	}

	func prefixes() -> AnySequence<[Element]> {
		return sequence(state: (self.makeIterator(), [])) { (state: inout (Iterator, [Element])) -> [Element]? in
			guard let next = state.0.next() else {
				return nil
			}
			state.1.append(next)
			return state.1
		}.collect(AnySequence.init)
	}
}

extension Sequence where Element: Hashable {
	func uniqueElements() -> AnySequence<Element> {
		return unique(by: {$0})
	}
}

func crossProduct<S1: Sequence, S2: Sequence>(_ lhs: S1, _ rhs: S2) -> AnySequence<(S1.Element, S2.Element)> {
	return sequence(
		state: (
			lhsIterator: lhs.makeIterator(),
			lhsElement: nil,
			rhsIterator: rhs.makeIterator(),
			rhsIteratorBase: rhs.makeIterator()
		)
	) { (state: (
		inout (
		lhsIterator: S1.Iterator,
		lhsElement: S1.Element?,
		rhsIterator: S2.Iterator,
		rhsIteratorBase: S2.Iterator
		)
		)) -> (S1.Element, S2.Element)? in
		guard let lhsElement = state.lhsElement ?? state.lhsIterator.next() else {
			return nil
		}
		state.lhsElement = lhsElement
		if let rhsElement = state.rhsIterator.next() {
			return (lhsElement, rhsElement)
		} else {
			state.rhsIterator = state.rhsIteratorBase
			
			guard let lhsNewElement = state.lhsIterator.next(), let rhsElement = state.rhsIterator.next() else {
				return nil
			}
			state.lhsElement = lhsNewElement
			return (lhsNewElement, rhsElement)
		}
	}.collect(AnySequence.init)
}

func crossMap<S1: Sequence, S2: Sequence, ElementOfResult>(_ lhs: S1, _ rhs: S2, transform: (S1.Element, S2.Element) throws -> ElementOfResult) rethrows -> [ElementOfResult] {
	var result: [ElementOfResult] = Array()
	result.reserveCapacity(lhs.underestimatedCount * rhs.underestimatedCount)
	for e1 in lhs {
		for e2 in rhs {
			try result.append(transform(e1, e2))
		}
	}
	return result
}

func crossFlatMap<S1: Sequence, S2: Sequence, ElementOfResult>(_ lhs: S1, _ rhs: S2, transform: (S1.Element, S2.Element) throws -> [ElementOfResult]) rethrows -> [ElementOfResult] {
	var result: [ElementOfResult] = Array()
	result.reserveCapacity(lhs.underestimatedCount * rhs.underestimatedCount)
	for e1 in lhs {
		for e2 in rhs {
			try result.append(contentsOf: transform(e1, e2))
		}
	}
	return result
}

func unzip<A, B, SequenceType: Sequence>(_ sequence: SequenceType) -> (AnySequence<A>, AnySequence<B>) where SequenceType.Element == (A, B) {
	return (sequence.lazy.map{$0.0}.collect(AnySequence.init), sequence.lazy.map{$0.1}.collect(AnySequence.init))
}

func unzip<A, B, SequenceType: Sequence>(_ sequence: SequenceType) -> ([A], [B]) where SequenceType.Element == (A, B) {
	return (sequence.map{$0.0}, sequence.map{$0.1})
}

func assertNonFatal(_ predicate: @autoclosure () -> Bool, _ message: String) {
#if DEBUG
	if !predicate() {
		print("[WARNING] \(message)")
	}
#endif
}
