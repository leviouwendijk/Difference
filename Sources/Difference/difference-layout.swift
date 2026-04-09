public struct DifferenceLayout: Sendable, Hashable {
    public struct Line: Sendable, Hashable {
        public let role: Role
        public let text: String

        public init(
            role: Role,
            text: String
        ) {
            self.role = role
            self.text = text
        }
    }

    public enum Role: String, Sendable, Codable, Hashable, CaseIterable {
        case headerOld
        case headerNew
        case equal
        case insert
        case delete
        case separator
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
