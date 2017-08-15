//
//  SyntaxTree.swift
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

public enum SyntaxTree<Element, LeafElement> {
	case leaf(LeafElement)
	indirect case node(key: Element, children: [SyntaxTree<Element, LeafElement>])
}

public extension SyntaxTree {
	
	public func map<Result>(_ transform: (Element) throws -> Result) rethrows -> SyntaxTree<Result, LeafElement> {
		switch self {
		case .leaf(let leaf):
			return .leaf(leaf)
			
		case .node(key: let key, children: let children):
			return try .node(key: transform(key), children: children.map{try $0.map(transform)})
		}
	}
	
	public func mapLeafs<Result>(_ transform: (LeafElement) throws -> Result) rethrows -> SyntaxTree<Element, Result> {
		switch self {
		case .leaf(let leaf):
			return try .leaf(transform(leaf))
			
		case .node(key: let key, children: let children):
			return try .node(key: key, children: children.map{try $0.mapLeafs(transform)})
		}
	}
	
	public func filter(_ predicate: (Element) throws -> Bool) rethrows -> SyntaxTree<Element, LeafElement>? {
		switch self {
		case .leaf(let element):
			return .leaf(element)
			
		case .node(key: let key, children: let children) where try predicate(key):
			return try .node(key: key, children: children.flatMap{try $0.filter(predicate)})
			
		case .node(key: _, children: _):
			return nil
		}
	}
	
	public func explode(_ shouldExplode: (Element) throws -> Bool) rethrows -> [SyntaxTree<Element, LeafElement>] {
		switch self {
		case .leaf:
			return [self]
			
		case .node(key: let key, children: let children) where try shouldExplode(key):
			return try children.flatMap{try $0.explode(shouldExplode)}
			
		case .node(key: let key, children: let children):
			return try [.node(key: key, children: children.flatMap{try $0.explode(shouldExplode)})]
		}
	}
	
	public func compressed() -> SyntaxTree<Element, LeafElement> {
		switch self {
		case .node(key: _, children: let children) where children.count == 1:
			let child = children[0]
			if case .leaf = child {
				return self
			} else {
				return child.compressed()
			}
			
		case .node(key: let key, children: let children):
			return .node(key: key, children: children.map{$0.compressed()})
			
		default:
			return self
		}
	}
}

extension SyntaxTree: CustomDebugStringConvertible {
	public var debugDescription: String {
		switch self {
		case .leaf(let value):
			return "leaf (value: \(value))"
			
		case .node(key: let key, children: let children):
			let childrenDescription = children.map(\.debugDescription).joined(separator: "\n").replacingOccurrences(of: "\n", with: "\n\t")
			return """
			node (key: \(key)) {
				\(childrenDescription)
			}
			"""
		}
	}
}

extension SyntaxTree: CustomStringConvertible {
	public var description: String {
		var id = 0
		let uniqueKeyTree = self.map { element -> (Int, Element) in
			let uniqueElement = (id, element)
			id += 1
			return uniqueElement
		}.mapLeafs { leaf -> (Int, LeafElement) in
			let uniqueLeaf = (id, leaf)
			id += 1
			return uniqueLeaf
		}
		
		
		func generateDescription(_ tree: SyntaxTree<(Int, Element), (Int, LeafElement)>) -> String {
			switch tree {
			case .leaf(let leaf):
				let (id, leafElement) = leaf
				return "node\(id) [label=\"\(leafElement)\" shape=box]"
				
			case .node(key: let key, children: let children):
				let (id, element) = key
				let childrenDescriptions = children.map(generateDescription).filter{!$0.isEmpty}.joined(separator: "\n")
				let childrenPointers = children.flatMap{ node -> Int? in
					if let id = node.root?.0 {
						return id
					} else if let id = node.leaf?.0 {
						return id
					} else {
						return nil
					}
				}.map{"node\(id) -> node\($0)"}.joined(separator: "\n")
				
				var result = "node\(id) [label=\"\(element)\"]"
				if !childrenPointers.isEmpty {
					result += "\n\(childrenPointers)"
				}
				if !childrenDescriptions.isEmpty {
					result += "\n\(childrenDescriptions)"
				}
				
				return result
			}
		}
		
		func allLeafIDs(_ tree: SyntaxTree<(Int, Element), (Int, LeafElement)>) -> [Int] {
			switch tree {
			case .leaf(let leaf):
				return [leaf.0]
				
			case .node(key: _, children: let children):
				return children.flatMap(allLeafIDs)
			}
		}
		
		return """
		digraph {
			\(generateDescription(uniqueKeyTree).replacingOccurrences(of: "\n", with: "\n\t"))
			{
				rank = same
				\(allLeafIDs(uniqueKeyTree).map(String.init).map{"node\($0)"}.joined(separator: "\n\t\t"))
			}
		}
		"""
	}
}

public func == <Element: Equatable, LeafElement: Equatable>(lhs: SyntaxTree<Element, LeafElement>, rhs: SyntaxTree<Element, LeafElement>) -> Bool {
	switch (lhs, rhs) {
	case (.leaf, .leaf):
		return true
		
	case (.node(key: let lKey, children: let lChildren), .node(key: let rKey, children: let rChildren)):
		return lKey == rKey && lChildren.count == rChildren.count && !zip(lChildren, rChildren).map(==).contains(false)
		
	default:
		return false
	}
}

public extension SyntaxTree {
	public init(key: Element, children: [SyntaxTree<Element, LeafElement>]) {
		self = .node(key: key, children: children)
	}
	
	public init(key: Element) {
		self = .node(key: key, children: [])
	}
	
	public init(value: LeafElement) {
		self = .leaf(value)
	}
}

public extension SyntaxTree where LeafElement == () {
	public init() {
		self = .leaf(())
	}
}

public extension SyntaxTree {
	public var root: Element? {
		guard case .node(key: let root, children: _) = self else {
			return nil
		}
		return root
	}
	
	public var leaf: LeafElement? {
		guard case .leaf(let leaf) = self else {
			return nil
		}
		return leaf
	}
}
