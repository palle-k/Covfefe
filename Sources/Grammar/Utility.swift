//
//  Utility.swift
//  GrammarTests
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
		return self.map { element -> Result in
			element[keyPath: keyPath]
		}
	}
	
	func filter(_ predicate: KeyPath<Element, Bool>) -> [Element] {
		return self.filter { element -> Bool in
			element[keyPath: predicate]
		}
	}
	
	func flatMap<Result>(_ keyPath: KeyPath<Element, Result?>) -> [Result] {
		return self.flatMap { element -> Result? in
			element[keyPath: keyPath]
		}
	}

	func flatMap<Result>(_ keyPath: KeyPath<Element, [Result]>) -> [Result] {
		return self.flatMap { element -> [Result] in
			element[keyPath: keyPath]
		}
	}
}

extension Sequence {
	func allMatch(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
		return try !self.contains(where: {try !predicate($0)})
	}
}

extension String {
	func matches(`for` pattern: String) throws -> [Range<String.Index>] {
		let expression = try NSRegularExpression(pattern: pattern, options: [])
		let range = NSRange(self.startIndex ..< self.endIndex, in: self)
		
		let matches = expression.matches(in: self, options: [], range: range)
		return matches.flatMap { match -> Range<String.Index>? in
			return Range(match.range, in: self)
		}
	}
	
	func hasRegularPrefix(_ pattern: String) throws -> Bool {
		return try matches(for: pattern).contains(where: { range -> Bool in
			range.lowerBound == self.startIndex
		})
	}
	
	func rangeOfRegularPrefix(_ pattern: String) throws -> Range<String.Index>? {
		return try matches(for: pattern).first(where: { range -> Bool in
			range.lowerBound == self.startIndex
		})
	}
	
	func hasRegularSuffix(_ pattern: String) throws -> Bool {
		return try matches(for: pattern).contains(where: { range -> Bool in
			range.upperBound == self.endIndex
		})
	}
	
	func rangeOfRegularSuffix(_ pattern: String) throws -> Range<String.Index>? {
		return try matches(for: pattern).first(where: { range -> Bool in
			range.upperBound == self.endIndex
		})
	}
	
	func hasPrefix(_ prefix: [Terminal]) -> Bool {
		let prefixString = prefix.map(\Terminal.value).joined()
		
		if prefix.contains(where: {$0.isRegularExpression}) {
			return try! self.hasRegularPrefix("^\(prefixString)")
		} else {
			return self.hasPrefix(prefixString)
		}
	}
	
	func rangeOfPrefix(_ prefix: [Terminal]) -> Range<String.Index>? {
		let prefixString = prefix.map(\Terminal.value).joined()
		
		if prefix.contains(where: {$0.isRegularExpression}) {
			return try! self.rangeOfRegularPrefix(prefixString)
		} else {
			return self.range(of: prefixString)
		}
	}
	
	func hasSuffix(_ suffix: [Terminal]) -> Bool {
		let suffixString = suffix.map(\Terminal.value).joined()
		
		if suffix.contains(where: {$0.isRegularExpression}) {
			return try! self.hasRegularSuffix("\(suffixString)$")
		} else {
			return self.hasSuffix(suffixString)
		}
	}
	
	func rangeOfSuffix(_ suffix: [Terminal]) -> Range<String.Index>? {
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

func unzip<A, B, SequenceType: Sequence>(_ sequence: SequenceType) -> (AnySequence<A>, AnySequence<B>) where SequenceType.Element == (A, B) {
	return (sequence.lazy.map{$0.0}.collect(AnySequence.init), sequence.lazy.map{$0.1}.collect(AnySequence.init))
}

func unzip<A, B, SequenceType: Sequence>(_ sequence: SequenceType) -> ([A], [B]) where SequenceType.Element == (A, B) {
	return (sequence.map{$0.0}, sequence.map{$0.1})
}
