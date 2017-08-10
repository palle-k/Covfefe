//
//  SyntaxTree.swift
//  Grammar
//
//  Created by Palle Klewitz on 07.08.17.
//

import Foundation

public enum Tree<Element, LeafElement> {
	case leaf(LeafElement)
	indirect case node(key: Element, children: [Tree<Element, LeafElement>])
}

public extension Tree {
	
	public func map<Result>(_ transform: (Element) throws -> Result) rethrows -> Tree<Result, LeafElement> {
		switch self {
		case .leaf(let leaf):
			return .leaf(leaf)
			
		case .node(key: let key, children: let children):
			return try .node(key: transform(key), children: children.map{try $0.map(transform)})
		}
	}
	
	public func mapLeafs<Result>(_ transform: (LeafElement) throws -> Result) rethrows -> Tree<Element, Result> {
		switch self {
		case .leaf(let leaf):
			return try .leaf(transform(leaf))
			
		case .node(key: let key, children: let children):
			return try .node(key: key, children: children.map{try $0.mapLeafs(transform)})
		}
	}
	
	public func filter(_ predicate: (Element) throws -> Bool) rethrows -> Tree<Element, LeafElement>? {
		switch self {
		case .leaf(let element):
			return .leaf(element)
			
		case .node(key: let key, children: let children) where try predicate(key):
			return try .node(key: key, children: children.flatMap{try $0.filter(predicate)})
			
		case .node(key: _, children: _):
			return nil
		}
	}
	
	public func explode(_ shouldExplode: (Element) throws -> Bool) rethrows -> [Tree<Element, LeafElement>] {
		switch self {
		case .leaf:
			return [self]
			
		case .node(key: let key, children: let children) where try shouldExplode(key):
			return try children.flatMap{try $0.explode(shouldExplode)}
			
		case .node(key: let key, children: let children):
			return try [.node(key: key, children: children.flatMap{try $0.explode(shouldExplode)})]
		}
	}
	
	public func compressed() -> Tree<Element, LeafElement> {
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

extension Tree: CustomDebugStringConvertible {
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

extension Tree: CustomStringConvertible {
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
		
		
		func generateDescription(_ tree: Tree<(Int, Element), (Int, LeafElement)>) -> String {
			switch tree {
			case .leaf(let leaf):
				let (id, leafElement) = leaf
				return "node\(id) [label=\"\(leafElement)\"]"
				
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
		
		func allLeafIDs(_ tree: Tree<(Int, Element), (Int, LeafElement)>) -> [Int] {
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
				rank = same;
				\(allLeafIDs(uniqueKeyTree).map(String.init).map{"node\($0)"}.joined(separator: "\n\t\t"))
			}
		}
		"""
	}
}

public func == <Element: Equatable, LeafElement: Equatable>(lhs: Tree<Element, LeafElement>, rhs: Tree<Element, LeafElement>) -> Bool {
	switch (lhs, rhs) {
	case (.leaf, .leaf):
		return true
		
	case (.node(key: let lKey, children: let lChildren), .node(key: let rKey, children: let rChildren)):
		return lKey == rKey && lChildren.count == rChildren.count && !zip(lChildren, rChildren).map(==).contains(false)
		
	default:
		return false
	}
}

public extension Tree {
	public init(key: Element, children: [Tree<Element, LeafElement>]) {
		self = .node(key: key, children: children)
	}
	
	public init(key: Element) {
		self = .node(key: key, children: [])
	}
	
	public init(value: LeafElement) {
		self = .leaf(value)
	}
}

public extension Tree where LeafElement == () {
	public init() {
		self = .leaf(())
	}
}

public extension Tree {
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
