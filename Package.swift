// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Covfefe",
	products: [
		.library(name: "Covfefe", type: .dynamic, targets: ["Covfefe"]),
	],
	dependencies: [
	],
	targets: [
		.target(name: "Covfefe", dependencies: []),
		.testTarget(name: "CovfefeTests", dependencies: ["Covfefe"]),
	]
)
