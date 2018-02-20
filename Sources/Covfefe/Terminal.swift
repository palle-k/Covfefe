//
//  Terminal.swift
//  Covfefe
//
//  Created by Palle Klewitz on 20.02.18.
//

import Foundation

public enum Terminal {
	case string(string: String, hash: Int)
	case characterRange(range: ClosedRange<Character>, hash: Int)
	case regularExpression(expression: NSRegularExpression, hash: Int)
}

public extension Terminal {
	init(string: String) {
		self = .string(string: string, hash: string.hashValue)
	}
	
	init(range: ClosedRange<Character>) {
		self = .characterRange(range: range, hash: range.hashValue)
	}
	
	init(expression: String) throws {
		let regex = try NSRegularExpression(pattern: expression, options: [])
		self = .regularExpression(expression: regex, hash: expression.hashValue)
	}
	
	var isEmpty: Bool {
		switch self {
		case .characterRange:
			return false
			
		case .regularExpression(let expression, _):
			return expression.pattern.isEmpty
			
		case .string(let string, _):
			return string.isEmpty
		}
	}
}

extension Terminal: ExpressibleByStringLiteral {
	public init(stringLiteral value: String) {
		self.init(string: value)
	}
}

extension Terminal: Hashable {
	public static func == (lhs: Terminal, rhs: Terminal) -> Bool {
		switch (lhs, rhs) {
		case (.string(string: let ls, hash: _), .string(string: let rs, hash: _)):
			return ls == rs
			
		case (.characterRange(range: let lr, hash: _), .characterRange(range: let rr, hash: _)):
			return lr == rr
			
		case (.regularExpression(expression: let le, hash: _), .regularExpression(expression: let re, hash: _)):
			return le.pattern == re.pattern
			
		default:
			return false
		}
	}
	
	public var hashValue: Int {
		switch self {
		case .characterRange(range: _, hash: let hash):
			return hash
			
		case .regularExpression(expression: _, hash: let hash):
			return hash
			
		case .string(string: _, hash: let hash):
			return hash
		}
	}
}

extension Terminal: CustomStringConvertible {
	public var description: String {
		switch self {
		case .string(let string, _):
			return string
			
		case .characterRange(let range, _):
			return "\(range.lowerBound) ... \(range.upperBound)"
			
		case .regularExpression(let expression, _):
			return expression.pattern
		}
	}
}

extension Terminal: Codable {
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		switch try container.decode(TerminalCoding.self, forKey: .type) {
		case .string:
			let string = try container.decode(String.self, forKey: .value)
			self = .string(string: string, hash: string.hashValue)
			
		case .characterRange:
			let range = try container.decode(ClosedRange<Character>.self, forKey: .value)
			self = .characterRange(range: range, hash: range.hashValue)
			
		case .regularExpression:
			let pattern = try container.decode(String.self, forKey: .value)
			self = try .regularExpression(expression: NSRegularExpression(pattern: pattern, options: []), hash: pattern.hashValue)
		}
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		
		switch self {
		case .string(let string, _):
			try container.encode(TerminalCoding.string, forKey: .type)
			try container.encode(string, forKey: .value)
			
		case .characterRange(let range, _):
			try container.encode(TerminalCoding.characterRange, forKey: .type)
			try container.encode(range, forKey: .value)
			
		case .regularExpression(let expression, _):
			try container.encode(TerminalCoding.regularExpression, forKey: .type)
			try container.encode(expression.pattern, forKey: .value)
		}
	}
	
	private enum CodingKeys: String, CodingKey {
		case type
		case value
	}
	
	private enum TerminalCoding: String, Codable {
		case string
		case characterRange
		case regularExpression
	}
}

extension ClosedRange: Codable where Bound == Character {
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let lower = try container.decode(String.self, forKey: .lowerBound)
		let upper = try container.decode(String.self, forKey: .upperBound)
		
		guard lower.count == 1 else {
			throw DecodingError.dataCorruptedError(forKey: .lowerBound, in: container, debugDescription: "lowerBound must be string of length 1")
		}
		guard upper.count == 1 else {
			throw DecodingError.dataCorruptedError(forKey: .upperBound, in: container, debugDescription: "upperBound must be string of length 1")
		}
		
		self.init(uncheckedBounds: (lower[lower.startIndex], upper[upper.startIndex]))
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		let lower = String(lowerBound)
		let upper = String(upperBound)
		try container.encode(lower, forKey: .lowerBound)
		try container.encode(upper, forKey: .upperBound)
	}
	
	private enum CodingKeys: String, CodingKey {
		case lowerBound
		case upperBound
	}
}

extension ClosedRange: Hashable where Bound: Hashable {
	public var hashValue: Int {
		return lowerBound.hashValue ^ upperBound.hashValue
	}
}
