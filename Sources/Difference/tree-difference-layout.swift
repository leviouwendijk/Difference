import Primitives

public struct TreeDifferenceLayout: Sendable, Codable, Hashable {
    public struct Line: Sendable, Codable, Hashable {
        /// Display-only descriptions; semantic positions remain in TreeDifference.Entry.
        public struct Relocation: Sendable, Codable, Hashable {
            public let from: String
            public let to: String

            public init(from: String, to: String) {
                self.from = from
                self.to = to
            }
        }

        public struct Presentation: Sendable, Codable, Hashable {
            public let label: String
            public let relocation: Relocation?

            public init(label: String, relocation: Relocation? = nil) {
                self.label = label
                self.relocation = relocation
            }
        }

        public let depth: Int
        public let is_last_child: Bool
        public let ancestor_last: [Bool]
        public let change: TreeChangeKind
        public let label: String
        public let id: String
        public let relocation: Relocation?
        public let movement_reasons: [TreeMovementReason]?

        public init(
            depth: Int,
            is_last_child: Bool,
            ancestor_last: [Bool],
            change: TreeChangeKind,
            label: String,
            id: String,
            relocation: Relocation? = nil,
            movement_reasons: [TreeMovementReason]? = nil
        ) {
            self.depth = depth
            self.is_last_child = is_last_child
            self.ancestor_last = ancestor_last
            self.change = change
            self.label = label
            self.id = id
            self.relocation = relocation
            self.movement_reasons = movement_reasons
        }
    }

    public let lines: [Line]

    public init(lines: [Line]) {
        self.lines = lines
    }

    public static func make<Value>(_ difference: TreeDifference<Value>) -> Self {
        make(difference, presenting: { .init(label: $0.label) })
    }

    public static func make<Value>(
        _ difference: TreeDifference<Value>,
        presenting: (TreeDifference<Value>.Entry) throws -> Line.Presentation
    ) rethrows -> Self {
        var lines: [Line] = []
        func visit(
            _ siblings: [Tree<TreeDifference<Value>.Entry>.Node],
            ancestors: [Bool]
        ) throws {
            for (index, node) in siblings.enumerated() {
                let last = index == siblings.count - 1
                let presentation = try presenting(node.value)
                lines.append(.init(
                    depth: ancestors.count,
                    is_last_child: last,
                    ancestor_last: ancestors,
                    change: node.value.change,
                    label: presentation.label,
                    id: node.value.id,
                    relocation: (node.value.change == .moved
                        || node.value.change == .moved_modified)
                        ? presentation.relocation
                        : nil,
                    movement_reasons: node.value.movement_reasons
                ))
                try visit(node.children, ancestors: ancestors + [last])
            }
        }
        try visit(difference.tree.roots, ancestors: [])
        return .init(lines: lines)
    }
}

public struct TreeDifferenceRenderPlan: Sendable, Hashable {
    public struct Segment: Sendable, Hashable {
        public enum Component: String, Sendable, Hashable {
            case marker
            case branch
            case label
            case relocation_from
            case relocation_separator
            case relocation_to
            case movement_delimiter
            case movement_reason
        }
        public let component: Component
        public let text: String
    }

    public struct Line: Sendable, Hashable {
        public let change: TreeChangeKind
        public let id: String
        public let segments: [Segment]
    }

    public let lines: [Line]

    public static func make(
        _ layout: TreeDifferenceLayout,
        show_movement_reasons: Bool = false
    ) -> Self {
        .init(lines: layout.lines.map { line in
            let branch = line.ancestor_last.dropLast().map { $0 ? "    " : "│   " }.joined()
                + (line.depth > 0 ? (line.is_last_child ? "└── " : "├── ") : "")
            let marker: String
            switch line.change {
            case .unchanged: marker = " "
            case .added: marker = "+"
            case .removed: marker = "-"
            case .modified: marker = "~"
            case .moved: marker = ">"
            case .moved_modified: marker = "*"
            }
            var segments: [Segment] = [
                .init(component: .marker, text: marker),
                .init(component: .branch, text: branch),
            ]
            if let relocation = line.relocation {
                segments.append(contentsOf: [
                    .init(component: .relocation_from, text: relocation.from),
                    .init(component: .relocation_separator, text: " -> "),
                    .init(component: .relocation_to, text: relocation.to),
                ])
            } else {
                segments.append(.init(component: .label, text: line.label))
            }
            if show_movement_reasons,
               line.change == .moved || line.change == .moved_modified,
               let reasons = line.movement_reasons,
               !reasons.isEmpty {
                segments.append(.init(component: .movement_delimiter, text: "  ["))
                segments.append(.init(
                    component: .movement_reason,
                    text: reasons.map(\.rawValue).joined(separator: ", ")
                ))
                segments.append(.init(component: .movement_delimiter, text: "]"))
            }
            return .init(change: line.change, id: line.id, segments: segments)
        })
    }
}

public enum TreeDifferenceRenderer {
    public static func render(_ plan: TreeDifferenceRenderPlan) -> String {
        plan.lines.map { line in
            guard line.segments.count >= 3 else {
                return line.segments.map(\.text).joined()
            }
            return "\(line.segments[0].text) \(line.segments.dropFirst().map(\.text).joined())"
        }.joined(separator: "\n")
    }

    public static func render<Value>(_ difference: TreeDifference<Value>) -> String {
        render(.make(.make(difference)))
    }
}
