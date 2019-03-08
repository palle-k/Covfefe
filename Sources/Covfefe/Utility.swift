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
    @available(*, unavailable, renamed: "allSatisfy")
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

fileprivate extension IteratorProtocol {
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
	
	// Improves code readability by transforming e.g. Set(a.map{...}.filter{...}) to a.map{...}.filter{...}.collect(Set.init)
	// so the order of reading equals the order of evaluation
	func collect<Result>(_ collector: (Self) throws -> Result) rethrows -> Result {
		return try collector(self)
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

extension Sequence where Element: Sequence {
	func combinations() -> [[Element.Element]] {
		func combine(_ iterator: Iterator, partialResult: [[Element.Element]]) -> [[Element.Element]] {
			var iterator = iterator
			guard let next = iterator.next() else {
				return partialResult
			}
			return combine(iterator, partialResult: crossProduct(partialResult, next).map{$0 + [$1]})
		}
		return combine(makeIterator(), partialResult: [[]])
	}
}

func crossProduct<S1: Sequence, S2: Sequence>(_ lhs: S1, _ rhs: S2) -> AnySequence<(S1.Element, S2.Element)> {
	return sequence(
		state: (
			lhsIterator: lhs.makeIterator(),
			lhsElement: Optional<S1.Element>.none,
			rhsIterator: rhs.makeIterator(),
			rhsIteratorBase: rhs.makeIterator()
		),
		next: { (state: inout (lhsIterator: S1.Iterator, lhsElement: S1.Element?, rhsIterator: S2.Iterator, rhsIteratorBase: S2.Iterator)) -> (S1.Element, S2.Element)? in
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
		}
	).collect(AnySequence.init)
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

func assertNonFatal(_ predicate: @autoclosure () -> Bool, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
#if DEBUG
	if !predicate() {
		print("[WARNING: \(file):\(function):\(line)] \(message)")
	}
#endif
}

extension Sequence {
	func partition(_ isInFirstPartition: (Element) throws -> Bool) rethrows -> ([Element], [Element]){
		return try reduce(into: ([],[])) { (partitions: inout ([Element], [Element]), element: Element) in
			if try isInFirstPartition(element) {
				partitions.0.append(element)
			} else {
				partitions.1.append(element)
			}
		}
	}
}

enum Either<A, B> {
	case first(A)
	case second(B)
}

extension Either {
	func map<ResultA, ResultB>(_ transformFirst: (A) throws -> ResultA, _ transformSecond: (B) throws -> ResultB) rethrows -> Either<ResultA, ResultB> {
		switch self {
		case .first(let a):
			return try .first(transformFirst(a))
			
		case .second(let b):
			return try .second(transformSecond(b))
		}
	}
	
	func combine<Result>(_ transformFirst: (A) throws -> Result, _ transformSecond: (B) throws -> Result) rethrows -> Result {
		switch self {
		case .first(let a):
			return try transformFirst(a)
			
		case .second(let b):
			return try transformSecond(b)
		}
	}
}

#if swift(>=4.1)
#else
extension Sequence {
	func compactMap<ElementOfResult>(_ transform: (Element) throws -> ElementOfResult?) rethrows -> [ElementOfResult] {
		return try flatMap(transform)
	}
}
#endif
