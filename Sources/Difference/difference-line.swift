public struct DifferenceLine: Sendable, Codable, Hashable {
    public enum Ending: String, Sendable, Codable, Hashable {
        case none
        case lf
        case crlf
        case cr
    }

    public let operation: DifferenceLineOperation
    public let text: String
    public let oldLine: Int?
    public let newLine: Int?
    /// Nil means unavailable (legacy or externally constructed lines), not no newline.
    public let ending: Ending?

    public init(
        operation: DifferenceLineOperation,
        text: String,
        oldLine: Int? = nil,
        newLine: Int? = nil,
        ending: Ending? = nil
    ) {
        self.operation = operation
        self.text = text
        self.oldLine = oldLine
        self.newLine = newLine
        self.ending = ending
    }
}
