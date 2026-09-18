public struct DifferenceLayout: Sendable, Codable, Hashable {
    public struct Line: Sendable, Codable, Hashable {
        public struct Coordinate:
            Sendable,
            Codable,
            Hashable
        {
            public let old: Int?
            public let new: Int?

            public init(
                old: Int? = nil,
                new: Int? = nil
            ) {
                self.old = old
                self.new = new
            }

            public static let none = Self()
        }

        public let role: Role
        public let text: String
        public let coordinate: Coordinate

        public init(
            role: Role,
            text: String,
            coordinate: Coordinate = .none
        ) {
            self.role = role
            self.text = text
            self.coordinate = coordinate
        }
    }

    public let lines: [Line]

    public init(
        lines: [Line]
    ) {
        self.lines = lines
    }
}

extension DifferenceLayout {
    public enum Role:
        String,
        Sendable,
        Codable,
        Hashable,
        CaseIterable
    {
        case headerOld
        case headerNew
        case equal
        case insert
        case delete
        case separator
        case endOfFile
    }
}

extension DifferenceLayout {
    public struct Changes:
        Sendable,
        Codable,
        Hashable
    {
        public struct Selection:
            Sendable,
            Codable,
            Hashable
        {
            public let layout: DifferenceLayout
            public let role: Role

            fileprivate init(
                layout: DifferenceLayout,
                role: Role
            ) {
                self.layout = layout
                self.role = role
            }

            public var lines: [Line] {
                layout.lines.filter {
                    $0.role == role
                }
            }

            public var coordinates: [Line.Coordinate] {
                lines.map(\.coordinate)
            }

            public var count: Int {
                lines.count
            }

            public var isEmpty: Bool {
                lines.isEmpty
            }
        }

        public let layout: DifferenceLayout

        public init(
            _ layout: DifferenceLayout
        ) {
            self.layout = layout
        }

        public var lines: [Line] {
            layout.lines.filter {
                $0.role == .insert
                    || $0.role == .delete
            }
        }

        public var coordinates: [Line.Coordinate] {
            lines.map(\.coordinate)
        }

        public var insertions: Selection {
            .init(
                layout: layout,
                role: .insert
            )
        }

        public var deletions: Selection {
            .init(
                layout: layout,
                role: .delete
            )
        }

        public var count: Int {
            lines.count
        }

        public var isEmpty: Bool {
            lines.isEmpty
        }
    }

    public var changes: Changes {
        .init(self)
    }
}

extension DifferenceLayout {
    public var hasChanges: Bool {
        !changes.isEmpty
    }

    public var isEmpty: Bool {
        lines.isEmpty
    }
}

// Compatibility aliases

extension DifferenceLayout.Line {
    @available(
        *,
        deprecated,
        message: "Use init(role:text:coordinate:)."
    )
    public init(
        role: DifferenceLayout.Role,
        text: String,
        oldLine: Int?,
        newLine: Int? = nil
    ) {
        self.init(
            role: role,
            text: text,
            coordinate: .init(
                old: oldLine,
                new: newLine
            )
        )
    }

    @available(
        *,
        deprecated,
        message: "Use init(role:text:coordinate:)."
    )
    public init(
        role: DifferenceLayout.Role,
        text: String,
        newLine: Int
    ) {
        self.init(
            role: role,
            text: text,
            coordinate: .init(
                new: newLine
            )
        )
    }

    @available(
        *,
        deprecated,
        message: "Use coordinate.old."
    )
    public var oldLine: Int? {
        coordinate.old
    }

    @available(
        *,
        deprecated,
        message: "Use coordinate.new."
    )
    public var newLine: Int? {
        coordinate.new
    }
}
