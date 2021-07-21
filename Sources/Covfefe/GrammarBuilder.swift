import Foundation

@resultBuilder
public final class GrammarBuilder {
    public static func buildBlock(_ components: [Production]...) -> [Production] {
        return Array(components.joined())
    }
}

extension Grammar {
    public init(start: NonTerminal, @GrammarBuilder builder: () throws ->[Production]) rethrows {
        self = Grammar(productions: try builder(), start: start)
    }
}