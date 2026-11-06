import Difference
import Foundation
import Primitives

private enum FixtureError: Error {
    case assertion(String)
    case presentation
}

@main
struct DifferenceGraphLayoutTests {
    static func main() throws {
        typealias G = Graph<String, String, String, String>

        func check(_ condition: Bool, _ message: String) throws {
            guard condition else { throw FixtureError.assertion(message) }
        }

        let before = try G(nodes: [
            .init(id: "a", value: "Alpha"),
            .init(id: "b", value: "Beta"),
            .init(id: "old", value: "Removed"),
        ], edges: [
            .init(id: "policy", source: "a", destination: "b", value: "ALLOW"),
            .init(id: "old-policy", source: "b", destination: "a", value: "BLOCK"),
        ])
        let after = try G(nodes: [
            .init(id: "a", value: "Alpha"),
            .init(id: "b", value: "Beta updated"),
            .init(id: "new", value: "Added"),
        ], edges: [
            .init(id: "policy", source: "b", destination: "a", value: "ALLOW"),
            .init(id: "new-policy", source: "a", destination: "b", value: "BLOCK"),
        ])

        let difference = GraphDiffer.make(
            before: before,
            after: after,
            equivalent_node: ==,
            equivalent_edge: ==
        )

        func project(
            _ difference: GraphDifference<String, String, String, String>,
            nodeID: @escaping (String) -> String = { $0 },
            edgeID: @escaping (String) -> String = { $0 },
            presentingNode: @escaping (String) throws -> GraphDifferenceLayout.Presentation = {
                .init(label: $0)
            }
        ) throws -> GraphDifferenceLayout {
            try .make(
                difference,
                nodeID: nodeID,
                edgeID: edgeID,
                presentingNode: presentingNode,
                presentingEdge: { .init(label: $0) }
            )
        }

        let layout = try project(difference)
        try check(layout.has_changes, "has_changes")
        try check(layout.nodes.map(\.id) == ["a", "b", "new", "old"], "node ordering")
        try check(layout.nodes.map(\.change) == [.unchanged, .modified, .added, .removed], "node changes")
        try check(layout.edges.map(\.id) == ["policy", "new-policy", "old-policy"], "edge ordering")
        try check(layout.edges.map(\.change) == [.modified, .added, .removed], "edge changes")
        try check(layout.nodes[1].before?.label == "Beta", "previous node presentation")
        try check(layout.nodes[1].after?.label == "Beta updated", "updated node presentation")
        try check(layout.edges[0].before?.endpoints == .init(source: "a", destination: "b"), "previous endpoints")
        try check(layout.edges[0].after?.endpoints == .init(source: "b", destination: "a"), "updated endpoints")
        try check(layout.edges[1].before == nil, "added edge absence")
        try check(layout.edges[2].after == nil, "removed edge absence")

        let restored = try JSONDecoder().decode(GraphDifferenceLayout.self, from: JSONEncoder().encode(layout))
        try check(restored == layout, "Codable roundtrip")

        let unchanged = GraphDiffer.make(before: before, after: before, equivalent_node: ==, equivalent_edge: ==)
        try check(!(try project(unchanged)).has_changes, "unchanged difference")

        do {
            _ = try project(difference, nodeID: { _ in "same" })
            throw FixtureError.assertion("duplicate node identity must throw")
        } catch GraphDifferenceLayoutError.duplicate_node_identity("same") {}

        do {
            _ = try project(difference, edgeID: { _ in "same" })
            throw FixtureError.assertion("duplicate edge identity must throw")
        } catch GraphDifferenceLayoutError.duplicate_edge_identity("same") {}

        do {
            _ = try project(difference, nodeID: { $0 == "a" ? "" : $0 })
            throw FixtureError.assertion("empty node identity must throw")
        } catch GraphDifferenceLayoutError.empty_node_identity {}

        do {
            _ = try project(difference, edgeID: { $0 == "policy" ? "" : $0 })
            throw FixtureError.assertion("empty edge identity must throw")
        } catch GraphDifferenceLayoutError.empty_edge_identity {}

        do {
            _ = try project(difference, presentingNode: { _ in throw FixtureError.presentation })
            throw FixtureError.assertion("presentation failures must propagate")
        } catch FixtureError.presentation {}

        let invalidEdge = G.Edge(id: "invalid", source: "missing", destination: "a", value: "ALLOW")
        let invalid = GraphDifference<String, String, String, String>(
            nodes: difference.nodes,
            edges: [.init(id: "invalid", change: .added, before: nil, after: invalidEdge)]
        )
        do {
            _ = try project(invalid)
            throw FixtureError.assertion("dangling endpoint must throw")
        } catch GraphDifferenceLayoutError.unknown_endpoint(edge: "invalid", node: "missing") {}

        let textLayout = DifferenceLayout(lines: [
            .init(role: .insert, text: "new line"),
            .init(role: .delete, text: "old line"),
        ])
        let treeLayout = TreeDifferenceLayout(lines: [
            .init(
                depth: 0,
                is_last_child: true,
                ancestor_last: [],
                change: .modified,
                label: "Root",
                id: "root"
            ),
        ])

        let presentation = DifferencePresentation(
            text: textLayout,
            tree: treeLayout,
            graph: layout
        )
        let summary = presentation.summary

        try check(!presentation.isEmpty, "aggregate is not empty")
        try check(presentation.has_changes, "aggregate reports changes")
        try check(summary.text?.insertions == 1, "text insertion count")
        try check(summary.text?.deletions == 1, "text deletion count")
        try check(summary.tree?.total == 1, "tree total")
        try check(summary.tree?.changed == 1, "tree changed count")
        try check(summary.graph?.nodes.total == 4, "graph node total")
        try check(summary.graph?.nodes.changed == 3, "graph changed nodes")
        try check(summary.graph?.edges.total == 3, "graph edge total")
        try check(summary.graph?.edges.changed == 3, "graph changed edges")
        try check(summary.has_changes, "typed summary changes")
        try check(
            presentation.changeSummary == "1 insertions, 1 deletions; tree: 1 changed of 1 nodes; graph: 3 changed of 4 nodes, 3 changed of 3 edges",
            "aggregate summary rendering"
        )

        let textOnly = DifferencePresentation(text: textLayout)
        try check(textOnly.changeSummary == "1 insertions, 1 deletions", "legacy text summary")
        try check(textOnly.has_changes, "text-only changes")

        let graphOnly = DifferencePresentation(graph: layout)
        try check(!graphOnly.isEmpty, "graph-only presentation")
        try check(graphOnly.has_changes, "graph-only changes")
        try check(
            graphOnly.changeSummary == "graph: 3 changed of 4 nodes, 3 changed of 3 edges",
            "graph-only summary"
        )

        let emptyPresentation = DifferencePresentation()
        try check(emptyPresentation.isEmpty, "empty aggregate")
        try check(!emptyPresentation.has_changes, "empty aggregate has no changes")
        try check(emptyPresentation.changeSummary == "no differences", "empty summary")

        let unchangedPresentation = DifferencePresentation(
            graph: try project(unchanged)
        )
        try check(!unchangedPresentation.isEmpty, "unchanged graph remains present")
        try check(!unchangedPresentation.has_changes, "unchanged graph reports no changes")
        try check(unchangedPresentation.summary.graph?.nodes.changed == 0, "unchanged node count")
        try check(unchangedPresentation.summary.graph?.edges.changed == 0, "unchanged edge count")

        let restoredPresentation = try JSONDecoder().decode(
            DifferencePresentation.self,
            from: JSONEncoder().encode(presentation)
        )
        try check(restoredPresentation == presentation, "aggregate Codable roundtrip")
        try check(restoredPresentation.summary == summary, "summary survives projection roundtrip")

        print("PASS GraphDifferenceLayout and DifferencePresentation")
    }
}
