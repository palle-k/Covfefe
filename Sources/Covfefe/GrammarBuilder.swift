import Foundation

/// Result builder that collects instances of `[Production]` and returns a joined instance of `[Production]`.
///
/// Use `-->`, `<|>` and `<+>` operators in order to declare operations. Symbols may be defined
/// using `t(_:)` for termanl expressions and `n(_:)` for non-terminal expressions on the right side of `-->`
/// operator.
///
/// Example:
/// ```swift
/// // Recognizes:
/// // ""
/// // "abc()"
/// // "abc(abd)((def))"
/// // etc... 
/// let grammar = Grammar(start: "S") {
///     "S" --> n("S") <+> n("S")
///         <|> t("(") <+> n("S") <+> t(")")
///         <|> n("OptLetters")
///
///     "OptLetters" --> t()
///                  <|> t(CharacterSet.letters) <+> n("OptLetters")
/// }
/// ```
///
///
/// For more complex examples, refer to `BNFImporter.swift`
@resultBuilder
public final class GrammarBuilder {
    public static func buildBlock(_ components: [Production]...) -> [Production] {
        return Array(components.joined())
    }
}

extension Grammar {

    /// Creates an instance representing a grammar provided in the builder block.
    /// - Parameters:
    ///   - start: Root non-terminal.
    ///   - builder: Builder block that defines the gammar. Refer to the documentation of
    ///   `GrammarBuilder` for information about syntax.
    /// - Throws: Initializer may throw if any statement in the builder throws.
    public init(start: NonTerminal, @GrammarBuilder builder: () throws ->[Production]) rethrows {
        self = Grammar(productions: try builder(), start: start)
    }
}
