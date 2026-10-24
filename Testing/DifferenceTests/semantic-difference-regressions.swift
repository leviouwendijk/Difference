import Difference
import Foundation
import Primitives

private struct DocumentNode: Sendable, Codable, Hashable {
    let id: String
    let label: String
}

func semantic_difference_regressions() throws {
    let before = Tree<DocumentNode>(roots: [
        .init(.init(id: "folder", label: "folder"), children: [
            .init(.init(id: "file", label: "file"))
        ])
    ])
    let after = Tree<DocumentNode>(roots: [
        .init(.init(id: "folder", label: "folder"), children: [
            .init(.init(id: "file", label: "file"))
        ])
    ])
    let tree = try TreeDiffer.make(
        before: before, after: after, source: .planned,
        identity: \.id, label: \.label,
        equivalent: { $0 == $1 }
    )
    let text = TextDiffer.diff(
        old: "before\n", new: "after\n",
        oldName: "a/folder/file", newName: "b/folder/file"
    )
    let document = try Difference(
        structure: tree,
        contents: [.init(id: "op-A", node_id: "file", difference: text)]
    )
    try expect(document.structure.source == .planned, "provenance survives")
    try expect(document.tree_layout.lines.map(\.id) == ["folder", "file"], "tree identities survive")
    try expect(
        document.tree_layout.lines.first(where: { $0.id == "file" })?.change == .modified,
        "content-only changes appear as modified in the tree view"
    )
    try expect(document.text_sections().map(\.node_id) == ["file"], "text sections retain identity")
    try expect(document.text_layout.changes.count == 2, "text projection retains changed lines")
    let roundtrip = try JSONDecoder().decode(
        Difference<DocumentNode>.self, from: JSONEncoder().encode(document)
    )
    try expect(roundtrip == document, "semantic identities and content survive serialization")

    do {
        _ = try Difference(
            structure: tree,
            contents: [.init(id: "op-A", node_id: "absent", difference: text)]
        )
        throw DifferenceError.unknown_content_node("failed to reject")
    } catch DifferenceError.unknown_content_node(let id) {
        try expect(id == "absent", "unknown text attachments rejected")
    }
    do {
        _ = try Difference(
            structure: tree,
            contents: [
                .init(id: "same-operation", node_id: "file", difference: text),
                .init(id: "same-operation", node_id: "file", difference: text)
            ]
        )
        throw DifferenceError.duplicate_content_identity("failed to reject")
    } catch DifferenceError.duplicate_content_identity(let id) {
        try expect(id == "same-operation", "duplicate operation identities rejected")
    }
    let repeated = try Difference(
        structure: tree,
        contents: [
            .init(id: "op-A", node_id: "file", difference: text),
            .init(id: "op-B", node_id: "file", difference: text)
        ]
    )
    try expect(repeated.text_sections().map(\.id) == ["op-A", "op-B"], "repeated operations retain their order and identity")
}
