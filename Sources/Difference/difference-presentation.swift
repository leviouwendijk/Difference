import Schema

/// Aggregates independent difference presentations without replacing their
/// semantic source differences or implying a merged topology.
public struct DifferencePresentation: Sendable, Codable, Hashable {
    public struct Count: Sendable, Codable, Hashable {
        public let total: Int
        public let changed: Int

        public init(total: Int, changed: Int) {
            self.total = total
            self.changed = changed
        }
    }

    public struct Summary: Sendable, Codable, Hashable, CustomStringConvertible {
        public struct Text: Sendable, Codable, Hashable {
            public let insertions: Int
            public let deletions: Int

            public init(insertions: Int, deletions: Int) {
                self.insertions = insertions
                self.deletions = deletions
            }
        }

        public struct Graph: Sendable, Codable, Hashable {
            public let nodes: Count
            public let edges: Count

            public init(nodes: Count, edges: Count) {
                self.nodes = nodes
                self.edges = edges
            }
        }

        public let text: Text?
        public let tree: Count?
        public let graph: Graph?

        public init(text: Text? = nil, tree: Count? = nil, graph: Graph? = nil) {
            self.text = text
            self.tree = tree
            self.graph = graph
        }

        public var has_changes: Bool {
            (text.map { $0.insertions > 0 || $0.deletions > 0 } ?? false)
                || (tree?.changed ?? 0) > 0
                || (graph.map { $0.nodes.changed > 0 || $0.edges.changed > 0 } ?? false)
        }

        public var description: String {
            var sections: [String] = []

            if let text {
                sections.append("\(text.insertions) insertions, \(text.deletions) deletions")
            }

            if let tree {
                sections.append("tree: \(tree.changed) changed of \(tree.total) nodes")
            }

            if let graph {
                sections.append(
                    "graph: \(graph.nodes.changed) changed of \(graph.nodes.total) nodes, \(graph.edges.changed) changed of \(graph.edges.total) edges"
                )
            }

            return sections.isEmpty ? "no differences" : sections.joined(separator: "; ")
        }
    }

    public let text: DifferenceLayout?
    public let tree: TreeDifferenceLayout?
    public let graph: GraphDifferenceLayout?

    public init(
        text: DifferenceLayout? = nil,
        tree: TreeDifferenceLayout? = nil,
        graph: GraphDifferenceLayout? = nil
    ) {
        self.text = text
        self.tree = tree
        self.graph = graph
    }

    public var isEmpty: Bool {
        (text?.isEmpty ?? true)
            && (tree?.lines.isEmpty ?? true)
            && (graph.map { $0.nodes.isEmpty && $0.edges.isEmpty } ?? true)
    }

    public var has_changes: Bool {
        summary.has_changes
    }

    public var summary: Summary {
        let textSummary: Summary.Text? = text.flatMap { layout in
            guard !layout.isEmpty else { return nil }
            return .init(
                insertions: layout.changes.insertions.count,
                deletions: layout.changes.deletions.count
            )
        }

        let treeSummary: Count? = tree.flatMap { layout in
            guard !layout.lines.isEmpty else { return nil }
            return .init(
                total: layout.lines.count,
                changed: layout.lines.filter { $0.change != .unchanged }.count
            )
        }

        let graphSummary: Summary.Graph? = graph.flatMap { layout in
            guard !layout.nodes.isEmpty || !layout.edges.isEmpty else { return nil }
            return .init(
                nodes: .init(
                    total: layout.nodes.count,
                    changed: layout.nodes.filter { $0.change != .unchanged }.count
                ),
                edges: .init(
                    total: layout.edges.count,
                    changed: layout.edges.filter { $0.change != .unchanged }.count
                )
            )
        }

        return .init(text: textSummary, tree: treeSummary, graph: graphSummary)
    }

    public var changeSummary: String {
        summary.description
    }
}

extension DifferencePresentation: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .object(
            properties: [
                .init(name: "text", schema: DifferenceLayout.jsonschema, required: false),
                .init(name: "tree", schema: TreeDifferenceLayout.jsonschema, required: false),
                .init(name: "graph", schema: GraphDifferenceLayout.jsonschema, required: false),
            ],
            additionalProperties: .disallowed
        )
    }
}
