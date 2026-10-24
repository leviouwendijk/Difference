import Primitives

public struct TreeDifferenceLayout: Sendable, Codable, Hashable {
    public struct Line: Sendable, Codable, Hashable {
        public let depth: Int
        public let is_last_child: Bool
        public let ancestor_last: [Bool]
        public let change: TreeChangeKind
        public let label: String
        public let id: String

        public init(
            depth: Int,
            is_last_child: Bool,
            ancestor_last: [Bool],
            change: TreeChangeKind,
            label: String,
            id: String
        ) {
            self.depth = depth
            self.is_last_child = is_last_child
            self.ancestor_last = ancestor_last
            self.change = change
            self.label = label
            self.id = id
        }
    }

    public let lines: [Line]

    public init(lines: [Line]) {
        self.lines = lines
    }

    public static func make<Value>(_ difference: TreeDifference<Value>) -> Self {
        var lines: [Line] = []
        func visit(
            _ siblings: [Tree<TreeDifference<Value>.Entry>.Node],
            ancestors: [Bool]
        ) {
            for (index, node) in siblings.enumerated() {
                let last = index == siblings.count - 1
                lines.append(.init(
                    depth: ancestors.count,
                    is_last_child: last,
                    ancestor_last: ancestors,
                    change: node.value.change,
                    label: node.value.label,
                    id: node.value.id
                ))
                visit(node.children, ancestors: ancestors + [last])
            }
        }
        visit(difference.tree.roots, ancestors: [])
        return .init(lines: lines)
    }
}

public struct TreeDifferenceRenderPlan: Sendable, Hashable {
    public struct Segment: Sendable, Hashable {
        public enum Component: String, Sendable, Hashable {
            case marker
            case branch
            case label
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

    public static func make(_ layout: TreeDifferenceLayout) -> Self {
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
            return .init(
                change: line.change,
                id: line.id,
                segments: [
                    .init(component: .marker, text: marker),
                    .init(component: .branch, text: branch),
                    .init(component: .label, text: line.label)
                ]
            )
        })
    }
}

public enum TreeDifferenceRenderer {
    public static func render(_ plan: TreeDifferenceRenderPlan) -> String {
        plan.lines.map { line in
            guard line.segments.count == 3 else {
                return line.segments.map(\.text).joined()
            }
            return "\(line.segments[0].text) \(line.segments[1].text)\(line.segments[2].text)"
        }.joined(separator: "\n")
    }

    public static func render<Value>(_ difference: TreeDifference<Value>) -> String {
        render(.make(.make(difference)))
    }
}
