public enum DifferenceLineRenderComponent:
    Sendable,
    Hashable,
    CaseIterable
{
    case lineNumbers
    case marker
    case border
    case text
}

public enum DifferenceLineNumberFormat:
    Sendable,
    Hashable,
    CaseIterable
{
    case compact
    case columns
}

public struct DifferenceRenderOptions: Sendable, Hashable {
    public var showHeader: Bool
    public var showUnchangedLines: Bool
    public var contextLineCount: Int
    public var collapseSeparator: String
    public var showEndOfFile: Bool

    public var lineComponents: [DifferenceLineRenderComponent]
    public var lineNumberFormat: DifferenceLineNumberFormat
    public var missingLineNumberCharacter: Character
    public var componentSpacing: Int

    public var equalMarker: String
    public var insertMarker: String
    public var deleteMarker: String
    public var border: String

    public init(
        showHeader: Bool = true,
        showUnchangedLines: Bool = false,
        contextLineCount: Int = 3,
        collapseSeparator: String = " ...",
        showEndOfFile: Bool = false,
        lineComponents: [DifferenceLineRenderComponent] = [
            .lineNumbers,
            .border,
            .marker,
            .text,
        ],
        lineNumberFormat: DifferenceLineNumberFormat = .compact,
        missingLineNumberCharacter: Character = "-",
        componentSpacing: Int = 1,
        equalMarker: String = " ",
        insertMarker: String = "+",
        deleteMarker: String = "-",
        border: String = "│"
    ) {
        self.showHeader = showHeader
        self.showUnchangedLines = showUnchangedLines
        self.contextLineCount = max(0, contextLineCount)
        self.collapseSeparator = collapseSeparator
        self.showEndOfFile = showEndOfFile
        self.lineComponents = Self.unique(
            lineComponents
        )
        self.lineNumberFormat = lineNumberFormat
        self.missingLineNumberCharacter = missingLineNumberCharacter
        self.componentSpacing = max(
            0,
            componentSpacing
        )
        self.equalMarker = equalMarker
        self.insertMarker = insertMarker
        self.deleteMarker = deleteMarker
        self.border = border
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

    public static let prefixedUnified: Self = .init(
        showHeader: true,
        showUnchangedLines: false,
        contextLineCount: 3,
        lineComponents: [
            .marker,
            .text,
        ],
        componentSpacing: 0,
        equalMarker: "   ",
        insertMarker: " + ",
        deleteMarker: " - "
    )

    public static let prefixedFull: Self = .init(
        showHeader: true,
        showUnchangedLines: true,
        contextLineCount: .max,
        lineComponents: [
            .marker,
            .text,
        ],
        componentSpacing: 0,
        equalMarker: "   ",
        insertMarker: " + ",
        deleteMarker: " - "
    )

    private static func unique(
        _ components: [DifferenceLineRenderComponent]
    ) -> [DifferenceLineRenderComponent] {
        var seen = Set<DifferenceLineRenderComponent>()

        return components.filter {
            seen.insert(
                $0
            ).inserted
        }
    }
}
