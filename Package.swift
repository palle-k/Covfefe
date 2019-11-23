// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Covfefe",
	products: [
		.library(name: "Covfefe", targets: ["Covfefe"]),
	],
	dependencies: [
	],
	targets: [
		.target(name: "Covfefe", dependencies: []),
		.testTarget(name: "CovfefeTests", dependencies: ["Covfefe"]),
	]
)
