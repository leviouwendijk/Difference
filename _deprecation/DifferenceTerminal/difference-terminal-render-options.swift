import Difference
import ANSI

@available(*, deprecated, message: "Use TerminalDifferenceRenderOptions from the Terminal package.")
public struct DifferenceTerminalStyle: Sendable, Hashable {
    public var headerColors: [ANSIColor]
    public var equalColors: [ANSIColor]
    public var insertColors: [ANSIColor]
    public var deleteColors: [ANSIColor]
    public var separatorColors: [ANSIColor]

    public init(
        headerColors: [ANSIColor] = [.brightBlack],
        equalColors: [ANSIColor] = [.dim],
        insertColors: [ANSIColor] = [.green],
        deleteColors: [ANSIColor] = [.red],
        separatorColors: [ANSIColor] = [.brightBlack]
    ) {
        self.headerColors = headerColors
        self.equalColors = equalColors
        self.insertColors = insertColors
        self.deleteColors = deleteColors
        self.separatorColors = separatorColors
    }

    public static let `default` = Self()
}

@available(*, deprecated, message: "Use TerminalDifferenceRenderOptions from the Terminal package.")
public struct DifferenceTerminalRenderOptions: Sendable, Hashable {
    public var base: DifferenceRenderOptions
    public var style: DifferenceTerminalStyle

    public init(
        base: DifferenceRenderOptions = .unified,
        style: DifferenceTerminalStyle = .default
    ) {
        self.base = base
        self.style = style
    }
}
