import Primitives

/// Graph differences compare canonical node and edge identities, not a tree
/// unfolding. Edge endpoints are part of relationship equivalence.
public enum GraphChangeKind: String, Sendable, Codable, Hashable, CaseIterable {
    case unchanged
    case added
    case removed
    case modified
}

public struct GraphDifference<NodeID: Hashable, NodeValue, EdgeID: Hashable, EdgeValue> {
    public struct NodeChange {
        public let id: NodeID
        public let change: GraphChangeKind
        public let before: Graph<NodeID, NodeValue, EdgeID, EdgeValue>.Node?
        public let after: Graph<NodeID, NodeValue, EdgeID, EdgeValue>.Node?

        public init(
            id: NodeID,
            change: GraphChangeKind,
            before: Graph<NodeID, NodeValue, EdgeID, EdgeValue>.Node?,
            after: Graph<NodeID, NodeValue, EdgeID, EdgeValue>.Node?
        ) {
            self.id = id
            self.change = change
            self.before = before
            self.after = after
        }
    }

    public struct EdgeChange {
        public let id: EdgeID
        public let change: GraphChangeKind
        public let before: Graph<NodeID, NodeValue, EdgeID, EdgeValue>.Edge?
        public let after: Graph<NodeID, NodeValue, EdgeID, EdgeValue>.Edge?

        public init(
            id: EdgeID,
            change: GraphChangeKind,
            before: Graph<NodeID, NodeValue, EdgeID, EdgeValue>.Edge?,
            after: Graph<NodeID, NodeValue, EdgeID, EdgeValue>.Edge?
        ) {
            self.id = id
            self.change = change
            self.before = before
            self.after = after
        }
    }

    /// New graph order, followed by entities present only in the old graph.
    public let nodes: [NodeChange]
    public let edges: [EdgeChange]

    public init(nodes: [NodeChange], edges: [EdgeChange]) {
        self.nodes = nodes
        self.edges = edges
    }

    public var has_changes: Bool {
        nodes.contains(where: { $0.change != .unchanged })
            || edges.contains(where: { $0.change != .unchanged })
    }
}

public enum GraphDiffer {
    public static func make<NodeID: Hashable, NodeValue, EdgeID: Hashable, EdgeValue>(
        before: Graph<NodeID, NodeValue, EdgeID, EdgeValue>,
        after: Graph<NodeID, NodeValue, EdgeID, EdgeValue>,
        equivalent_node: (NodeValue, NodeValue) -> Bool,
        equivalent_edge: (EdgeValue, EdgeValue) -> Bool
    ) -> GraphDifference<NodeID, NodeValue, EdgeID, EdgeValue> {
        typealias Delta = GraphDifference<NodeID, NodeValue, EdgeID, EdgeValue>
        let old = before.index
        let new_node_ids = Set(after.nodes.map(\.id))
        let new_edge_ids = Set(after.edges.map(\.id))

        let current_nodes: [Delta.NodeChange] = after.nodes.map { current in
            let previous = old.node(current.id)
            let change: GraphChangeKind
            if let previous {
                change = equivalent_node(previous.value, current.value) ? .unchanged : .modified
            } else {
                change = .added
            }
            return .init(id: current.id, change: change, before: previous, after: current)
        }
        let removed_nodes: [Delta.NodeChange] = before.nodes
            .filter { !new_node_ids.contains($0.id) }
            .map { previous in
                .init(id: previous.id, change: .removed, before: previous, after: nil)
            }
        let current_edges: [Delta.EdgeChange] = after.edges.map { current in
            let previous = old.edge(current.id)
            let change: GraphChangeKind
            if let previous {
                let same_endpoints = previous.source == current.source
                    && previous.destination == current.destination
                change = same_endpoints && equivalent_edge(previous.value, current.value)
                    ? .unchanged : .modified
            } else {
                change = .added
            }
            return .init(id: current.id, change: change, before: previous, after: current)
        }
        let removed_edges: [Delta.EdgeChange] = before.edges
            .filter { !new_edge_ids.contains($0.id) }
            .map { previous in
                .init(id: previous.id, change: .removed, before: previous, after: nil)
            }
        let nodes = current_nodes + removed_nodes
        let edges = current_edges + removed_edges
        return .init(nodes: nodes, edges: edges)
    }
}

extension GraphDifference.NodeChange: Sendable where NodeID: Sendable, NodeValue: Sendable, EdgeID: Sendable, EdgeValue: Sendable {}
extension GraphDifference.EdgeChange: Sendable where NodeID: Sendable, NodeValue: Sendable, EdgeID: Sendable, EdgeValue: Sendable {}
extension GraphDifference: Sendable where NodeID: Sendable, NodeValue: Sendable, EdgeID: Sendable, EdgeValue: Sendable {}

extension GraphDifference.NodeChange: Equatable where NodeValue: Equatable, EdgeValue: Equatable {}
extension GraphDifference.EdgeChange: Equatable where NodeValue: Equatable, EdgeValue: Equatable {}
extension GraphDifference: Equatable where NodeValue: Equatable, EdgeValue: Equatable {}

extension GraphDifference.NodeChange: Hashable where NodeValue: Hashable, EdgeValue: Hashable {}
extension GraphDifference.EdgeChange: Hashable where NodeValue: Hashable, EdgeValue: Hashable {}
extension GraphDifference: Hashable where NodeValue: Hashable, EdgeValue: Hashable {}

extension GraphDifference.NodeChange: Codable where NodeID: Codable, NodeValue: Codable, EdgeID: Codable, EdgeValue: Codable {}
extension GraphDifference.EdgeChange: Codable where NodeID: Codable, NodeValue: Codable, EdgeID: Codable, EdgeValue: Codable {}
extension GraphDifference: Codable where NodeID: Codable, NodeValue: Codable, EdgeID: Codable, EdgeValue: Codable {}
