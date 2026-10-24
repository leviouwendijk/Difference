import Primitives

/// A semantic difference whose structure and content can be rendered independently.
/// Node IDs connect content changes to their typed before/after tree entries.
public struct Difference<Value> {
    public struct ContentChange: Sendable, Codable, Hashable {
        /// Distinguishes multiple operations affecting the same semantic node.
        public let id: String
        public let node_id: String
        public let difference: TextDifference

        public init(id: String, node_id: String, difference: TextDifference) {
            self.id = id
            self.node_id = node_id
            self.difference = difference
        }
    }

    public struct TextSection: Sendable, Codable, Hashable {
        public let id: String
        public let node_id: String
        public let layout: DifferenceLayout

        public init(id: String, node_id: String, layout: DifferenceLayout) {
            self.id = id
            self.node_id = node_id
            self.layout = layout
        }
    }

    public let structure: TreeDifference<Value>
    /// Stored in caller-supplied order. No flattened layout is stored as truth.
    public let contents: [ContentChange]

    public init(
        structure: TreeDifference<Value>,
        contents: [ContentChange] = []
    ) throws {
        var node_ids: Set<String> = []
        for located in structure.tree.walk() {
            let id = located.node.value.id
            guard !id.isEmpty else {
                throw DifferenceError.empty_node_identity
            }
            guard node_ids.insert(id).inserted else {
                throw DifferenceError.duplicate_node_identity(id)
            }
        }
        var content_ids: Set<String> = []
        for content in contents {
            guard node_ids.contains(content.node_id) else {
                throw DifferenceError.unknown_content_node(content.node_id)
            }
            guard !content.id.isEmpty else {
                throw DifferenceError.empty_content_identity
            }
            guard content_ids.insert(content.id).inserted else {
                throw DifferenceError.duplicate_content_identity(content.id)
            }
        }
        self.structure = structure
        self.contents = contents
    }

    /// Derived presentation forms. Neither view is stored as semantic truth.
    public struct Layout: Sendable, Codable, Hashable {
        public let text: DifferenceLayout
        public let tree: TreeDifferenceLayout
    }

    public var layout: Layout {
        .init(
            text: make_text_layout(),
            tree: make_tree_layout()
        )
    }

    public func make_tree_layout() -> TreeDifferenceLayout {
        // A content-only edit changes the file even when its path is unchanged.
        let modified_ids = Set(contents.filter {
            $0.difference.hasChanges
        }.map(\.node_id))
        let structural = TreeDifferenceLayout.make(structure)
        return .init(lines: structural.lines.map { line in
            let change: TreeChangeKind
            if modified_ids.contains(line.id) {
                switch line.change {
                case .unchanged: change = .modified
                case .moved: change = .moved_modified
                default: change = line.change
                }
            } else {
                change = line.change
            }
            return .init(
                depth: line.depth,
                is_last_child: line.is_last_child,
                ancestor_last: line.ancestor_last,
                change: change,
                label: line.label,
                id: line.id
            )
        })
    }

    public func text_sections(
        options: DifferenceRenderOptions = .unified
    ) -> [TextSection] {
        contents.map { content in
            .init(
                id: content.id,
                node_id: content.node_id,
                layout: .make(content.difference, options: options)
            )
        }
    }

    public func make_text_layout(
        options: DifferenceRenderOptions = .unified
    ) -> DifferenceLayout {
        var lines: [DifferenceLayout.Line] = []
        for section in text_sections(options: options) {
            if !lines.isEmpty {
                lines.append(.init(role: .separator, text: ""))
            }
            lines.append(contentsOf: section.layout.lines)
        }
        return .init(lines: lines)
    }
}

public enum DifferenceError: Error, Sendable, Equatable {
    case empty_node_identity
    case duplicate_node_identity(String)
    case unknown_content_node(String)
    case empty_content_identity
    case duplicate_content_identity(String)
}

extension Difference: Sendable where Value: Sendable {}
extension Difference: Codable where Value: Codable {}
extension Difference: Equatable where Value: Equatable {}
extension Difference: Hashable where Value: Hashable {}
