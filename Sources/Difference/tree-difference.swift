import Primitives

public enum TreeChangeKind: String, Sendable, Codable, Hashable, CaseIterable {
    case unchanged
    case added
    case removed
    case modified
    case moved
    case moved_modified
}

public enum TreeDifferenceSource: String, Sendable, Codable, Hashable, CaseIterable {
    case observed
    case planned
    case applied
    case proposed
}

public struct TreeDifference<Value> {
    public struct Entry {
        public let id: String
        public let label: String
        public let change: TreeChangeKind
        public let before: Value?
        public let after: Value?
        public let before_address: TreeAddress?
        public let after_address: TreeAddress?

        public init(
            id: String,
            label: String,
            change: TreeChangeKind,
            before: Value?,
            after: Value?,
            before_address: TreeAddress? = nil,
            after_address: TreeAddress? = nil
        ) {
            self.id = id
            self.label = label
            self.change = change
            self.before = before
            self.after = after
            self.before_address = before_address
            self.after_address = after_address
        }
    }

    public let tree: Tree<Entry>
    public let source: TreeDifferenceSource

    public init(tree: Tree<Entry>, source: TreeDifferenceSource) {
        self.tree = tree
        self.source = source
    }
}

extension TreeDifference.Entry: Sendable where Value: Sendable {}
extension TreeDifference: Sendable where Value: Sendable {}
extension TreeDifference.Entry: Codable where Value: Codable {}
extension TreeDifference: Codable where Value: Codable {}
extension TreeDifference.Entry: Equatable where Value: Equatable {}
extension TreeDifference: Equatable where Value: Equatable {}
extension TreeDifference.Entry: Hashable where Value: Hashable {}
extension TreeDifference: Hashable where Value: Hashable {}

public enum TreeDifferenceError: Error, Sendable, Equatable {
    case duplicate_identity(String)
    case empty_identity
    case missing_identity(String)
}

public enum TreeDiffer {
    public static func make<Value>(
        before: Tree<Value>,
        after: Tree<Value>,
        source: TreeDifferenceSource = .observed,
        identity: (Value) -> String,
        label: (Value) -> String,
        equivalent: (Value, Value) -> Bool
    ) throws -> TreeDifference<Value> {
        let old_index = try index(before, identity: identity)
        let new_index = try index(after, identity: identity)

        func make_node(_ id: String) throws -> Tree<TreeDifference<Value>.Entry>.Node {
            let old = old_index.by_id[id]
            let new = new_index.by_id[id]
            let moved = old != nil && new != nil && old?.parent_id != new?.parent_id
            let modified: Bool
                if let old, let new {
                    modified = !equivalent(old.value, new.value)
                } else {
                    modified = false
                }
            let change: TreeChangeKind
            switch (old != nil, new != nil, moved, modified) {
            case (false, true, _, _): change = .added
            case (true, false, _, _): change = .removed
            case (true, true, true, true): change = .moved_modified
            case (true, true, true, false): change = .moved
            case (true, true, false, true): change = .modified
            default: change = .unchanged
            }

            let children: [String]
            if let new {
                // New topology is authoritative; retain old-only children at the end.
                let new_children = new.children
                let old_only = (old?.children ?? []).filter { new_index.by_id[$0] == nil }
                children = new_children + old_only
            } else {
                children = (old?.children ?? []).filter { new_index.by_id[$0] == nil }
            }

            guard let value = new?.value ?? old?.value else {
                throw TreeDifferenceError.missing_identity(id)
            }
            return .init(
                .init(
                    id: id,
                    label: label(value),
                    change: change,
                    before: old?.value,
                    after: new?.value,
                    before_address: old?.address,
                    after_address: new?.address
                ),
                children: try children.map(make_node)
            )
        }

        let old_only_roots = old_index.roots.filter { new_index.by_id[$0] == nil }
        let roots = new_index.roots + old_only_roots
        return .init(
            tree: .init(roots: try roots.map(make_node)),
            source: source
        )
    }

    private struct IndexedNode<Value> {
        let value: Value
        let address: TreeAddress
        let parent_id: String?
        let children: [String]
    }

    private struct IndexedTree<Value> {
        let roots: [String]
        let by_id: [String: IndexedNode<Value>]
    }

    private static func index<Value>(
        _ tree: Tree<Value>,
        identity: (Value) -> String
    ) throws -> IndexedTree<Value> {
        var by_id: [String: IndexedNode<Value>] = [:]
        var id_at_address: [TreeAddress: String] = [:]
        var roots: [String] = []
        for located in tree.walk() {
            let id = identity(located.node.value)
            guard !id.isEmpty else { throw TreeDifferenceError.empty_identity }
            guard by_id[id] == nil else {
                throw TreeDifferenceError.duplicate_identity(id)
            }
            let address = located.address
            let parent_id = address.parent.flatMap { id_at_address[$0] }
            let child_ids = located.node.children.map { identity($0.value) }
            by_id[id] = .init(
                value: located.node.value,
                address: address,
                parent_id: parent_id,
                children: child_ids
            )
            id_at_address[address] = id
            if address.parent == nil { roots.append(id) }
        }
        return .init(roots: roots, by_id: by_id)
    }
}
