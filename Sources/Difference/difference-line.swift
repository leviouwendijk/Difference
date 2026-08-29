public struct DifferenceLine: Sendable, Codable, Hashable {
    public let operation: DifferenceLineOperation
    public let text: String
    public let oldLine: Int?
    public let newLine: Int?

    public init(
        operation: DifferenceLineOperation,
        text: String,
        oldLine: Int? = nil,
        newLine: Int? = nil
    ) {
        self.operation = operation
        self.text = text
        self.oldLine = oldLine
        self.newLine = newLine
    }
}
