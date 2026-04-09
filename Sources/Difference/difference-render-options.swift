public struct DifferenceRenderOptions: Sendable, Hashable {
    public var showHeader: Bool
    public var showUnchangedLines: Bool
    public var contextLineCount: Int
    public var collapseSeparator: String

    public var equalPrefix: String
    public var insertPrefix: String
    public var deletePrefix: String

    public init(
        showHeader: Bool = true,
        showUnchangedLines: Bool = false,
        contextLineCount: Int = 3,
        collapseSeparator: String = " ...",
        equalPrefix: String = "   ",
        insertPrefix: String = " + ",
        deletePrefix: String = " - "
    ) {
        self.showHeader = showHeader
        self.showUnchangedLines = showUnchangedLines
        self.contextLineCount = max(0, contextLineCount)
        self.collapseSeparator = collapseSeparator
        self.equalPrefix = equalPrefix
        self.insertPrefix = insertPrefix
        self.deletePrefix = deletePrefix
    }

    public static let unified: Self = .init(
        showHeader: true,
        showUnchangedLines: false,
        contextLineCount: 3
    )

    public static let full: Self = .init(
        showHeader: true,
        showUnchangedLines: true,
        contextLineCount: .max
    )
}
