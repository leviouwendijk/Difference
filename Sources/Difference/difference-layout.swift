public struct DifferenceLayout: Sendable, Codable, Hashable {
    public struct Line: Sendable, Codable, Hashable {
        public let role: Role
        public let text: String
        public let oldLine: Int?
        public let newLine: Int?

        public init(
            role: Role,
            text: String,
            oldLine: Int? = nil,
            newLine: Int? = nil
        ) {
            self.role = role
            self.text = text
            self.oldLine = oldLine
            self.newLine = newLine
        }
    }

    public enum Role: String, Sendable, Codable, Hashable, CaseIterable {
        case headerOld
        case headerNew
        case equal
        case insert
        case delete
        case separator
        case endOfFile
    }

    public let lines: [Line]

    public init(
        lines: [Line]
    ) {
        self.lines = lines
    }

    public var isEmpty: Bool {
        lines.isEmpty
    }
}
