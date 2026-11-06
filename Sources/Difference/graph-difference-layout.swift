import Primitives

/// A serializable, presentation-only projection of GraphDifference.
/// It does not replace the semantic difference or calculate geometry.
public struct GraphDifferenceLayout: Sendable, Codable, Hashable {
    public struct Presentation: Sendable, Codable, Hashable {
        public let label: String
        public let detail: String?

        public init(label: String, detail: String? = nil) {
            self.label = label
            self.detail = detail
        }
    }

    public struct Endpoints: Sendable, Codable, Hashable {
        public let source: String
        public let destination: String

        public init(source: String, destination: String) {
            self.source = source
            self.destination = destination
        }
    }

    public struct Node: Sendable, Codable, Hashable {
        public let id: String
        public let change: GraphChangeKind
        public let before: Presentation?
        public let after: Presentation?

        public init(id: String, change: GraphChangeKind, before: Presentation?, after: Presentation?) {
            self.id = id
            self.change = change
            self.before = before
            self.after = after
        }
    }

    public struct Edge: Sendable, Codable, Hashable {
        public struct State: Sendable, Codable, Hashable {
            public let endpoints: Endpoints
            public let presentation: Presentation

            public init(endpoints: Endpoints, presentation: Presentation) {
                self.endpoints = endpoints
                self.presentation = presentation
            }
        }

        public let id: String
        public let change: GraphChangeKind
        public let before: State?
        public let after: State?

        public init(id: String, change: GraphChangeKind, before: State?, after: State?) {
            self.id = id
            self.change = change
            self.before = before
            self.after = after
        }
    }

    /// Preserves GraphDiffer ordering: current elements followed by removals.
    public let nodes: [Node]
    public let edges: [Edge]

    public init(nodes: [Node], edges: [Edge]) {
        self.nodes = nodes
        self.edges = edges
    }

    public var has_changes: Bool {
        nodes.contains { $0.change != .unchanged }
            || edges.contains { $0.change != .unchanged }
    }

    /// Identity projections must be unique. Presentation closures explicitly
    /// control what information is exposed to callers and model previews.
    public static func make<NodeID: Hashable, NodeValue, EdgeID: Hashable, EdgeValue>(
        _ difference: GraphDifference<NodeID, NodeValue, EdgeID, EdgeValue>,
        nodeID: (NodeID) -> String,
        edgeID: (EdgeID) -> String,
        presentingNode: (NodeValue) throws -> Presentation,
        presentingEdge: (EdgeValue) throws -> Presentation
    ) throws -> Self {
        var nodeIDs = Set<String>()
        let nodes = try difference.nodes.map { entry -> Node in
            let id = nodeID(entry.id)
            guard !id.isEmpty else {
                throw GraphDifferenceLayoutError.empty_node_identity
            }
            guard nodeIDs.insert(id).inserted else {
                throw GraphDifferenceLayoutError.duplicate_node_identity(id)
            }
            return try .init(
                id: id,
                change: entry.change,
                before: entry.before.map { try presentingNode($0.value) },
                after: entry.after.map { try presentingNode($0.value) }
            )
        }

        var edgeIDs = Set<String>()
        let edges = try difference.edges.map { entry -> Edge in
            let id = edgeID(entry.id)
            guard !id.isEmpty else {
                throw GraphDifferenceLayoutError.empty_edge_identity
            }
            guard edgeIDs.insert(id).inserted else {
                throw GraphDifferenceLayoutError.duplicate_edge_identity(id)
            }

            func state(
                _ edge: Graph<NodeID, NodeValue, EdgeID, EdgeValue>.Edge
            ) throws -> Edge.State {
                let source = nodeID(edge.source)
                let destination = nodeID(edge.destination)
                for endpoint in [source, destination] {
                    guard nodeIDs.contains(endpoint) else {
                        throw GraphDifferenceLayoutError.unknown_endpoint(edge: id, node: endpoint)
                    }
                }
                return try .init(
                    endpoints: .init(source: source, destination: destination),
                    presentation: presentingEdge(edge.value)
                )
            }

            return try .init(
                id: id,
                change: entry.change,
                before: entry.before.map(state),
                after: entry.after.map(state)
            )
        }
        return .init(nodes: nodes, edges: edges)
    }
}

public enum GraphDifferenceLayoutError: Error, Sendable, Equatable {
    case empty_node_identity
    case duplicate_node_identity(String)
    case empty_edge_identity
    case duplicate_edge_identity(String)
    case unknown_endpoint(edge: String, node: String)
}
