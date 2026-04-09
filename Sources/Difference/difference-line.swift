public struct DifferenceLine: Sendable, Codable, Hashable {
    public let operation: DifferenceLineOperation
    public let text: String

    public init(
        operation: DifferenceLineOperation,
        text: String
    ) {
        self.operation = operation
        self.text = text
    }
}
