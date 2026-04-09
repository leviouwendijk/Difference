public struct TextDifference: Sendable, Codable, Hashable {
    public let oldName: String
    public let newName: String
    public let lines: [DifferenceLine]

    public init(
        oldName: String,
        newName: String,
        lines: [DifferenceLine]
    ) {
        self.oldName = oldName
        self.newName = newName
        self.lines = lines
    }

    public var hasChanges: Bool {
        lines.contains(where: { $0.operation != .equal })
    }

    public var insertions: Int {
        lines.reduce(into: 0) { count, line in
            if line.operation == .insert {
                count += 1
            }
        }
    }

    public var deletions: Int {
        lines.reduce(into: 0) { count, line in
            if line.operation == .delete {
                count += 1
            }
        }
    }

    public var unchanged: Int {
        lines.reduce(into: 0) { count, line in
            if line.operation == .equal {
                count += 1
            }
        }
    }

    public var changeCount: Int {
        insertions + deletions
    }

    public var isEmpty: Bool {
        lines.isEmpty
    }
}
