import Primitives

public struct TreeAlternative<Value> {
    public let id: String
    public let label: String
    public let after: Tree<Value>
    public let source: TreeDifferenceSource

    public init(
        id: String,
        label: String,
        after: Tree<Value>,
        source: TreeDifferenceSource = .proposed
    ) {
        self.id = id
        self.label = label
        self.after = after
        self.source = source
    }
}

extension TreeDiffer {
    /// Builds every delta from the exact same original tree.
    public static func make_alternatives<Value>(
        before: Tree<Value>,
        baseline: DifferenceBaseline,
        candidates: [TreeAlternative<Value>],
        identity: (Value) -> String,
        label: (Value) -> String,
        equivalent: (Value, Value) -> Bool
    ) throws -> DifferenceAlternatives<TreeDifference<Value>> {
        let differences = try candidates.map { candidate in
            DifferenceAlternatives<TreeDifference<Value>>.Candidate(
                id: candidate.id,
                label: candidate.label,
                difference: try make(
                    before: before,
                    after: candidate.after,
                    source: candidate.source,
                    identity: identity,
                    label: label,
                    equivalent: equivalent
                )
            )
        }
        return try .init(baseline: baseline, candidates: differences)
    }
}

/// Identity-aligned alternative projection; it does NOT invent a merged topology.
/// The original node order is preserved, followed by candidate-only nodes.
public struct TreeDifferenceAlternativesLayout<Value> {
    public struct CandidateState {
        public let id: String
        public let label: String
        /// Nil means absent from both the baseline and this candidate.
        public let change: TreeChangeKind?
        public let entry_label: String?
        public let before: Value?
        public let after: Value?
        public let before_address: TreeAddress?
        public let after_address: TreeAddress?
        public let before_parent_id: String?
        public let after_parent_id: String?
    }

    public struct Line {
        public let id: String
        public let label: String
        public let baseline_address: TreeAddress?
        public let candidates: [CandidateState]
    }

    public let baseline: DifferenceBaseline
    public let lines: [Line]

    private struct NodeState {
        let entry: TreeDifference<Value>.Entry
        let before_parent_id: String?
        let after_parent_id: String?
    }

    private struct Index {
        let order: [String]
        let entries: [String: NodeState]
    }

    /// Compare original values with caller-defined equivalence; candidate values
    /// and candidate-specific after topology are intentionally not compared.
    public static func make(
        _ alternatives: DifferenceAlternatives<TreeDifference<Value>>,
        baseline_equivalent: (Value, Value) -> Bool
    ) throws -> Self {
        let indices = alternatives.candidates.map { make_index($0.difference) }
        var original_addresses: [String: TreeAddress] = [:]
        var original_values: [String: Value] = [:]
        var labels: [String: String] = [:]
        var additional_ids: [String] = []
        var seen = Set<String>()

        for index in indices {
            for id in index.order {
                guard let state = index.entries[id] else { continue }
                if let before_address = state.entry.before_address {
                    guard let before_value = state.entry.before else {
                        throw DifferenceAlternativesError.inconsistent_baseline(id)
                    }
                    if let earlier = original_addresses[id], earlier != before_address {
                        throw DifferenceAlternativesError.inconsistent_baseline(id)
                    }
                    if let earlier = original_values[id],
                       !baseline_equivalent(earlier, before_value) {
                        throw DifferenceAlternativesError.inconsistent_baseline(id)
                    }
                    original_addresses[id] = before_address
                    original_values[id] = before_value
                } else if original_addresses[id] != nil || state.entry.before != nil {
                    throw DifferenceAlternativesError.inconsistent_baseline(id)
                }
                if labels[id] == nil { labels[id] = state.entry.label }
                if seen.insert(id).inserted { additional_ids.append(id) }
            }
        }

        // Reject different originals masquerading as a shared baseline when one
        // candidate omits an original identity entirely.
        for (id, _) in original_addresses {
            for index in indices {
                guard index.entries[id]?.entry.before_address != nil else {
                    throw DifferenceAlternativesError.inconsistent_baseline(id)
                }
            }
        }

        let original_ids = original_addresses.keys.sorted { lhs, rhs in
            guard let left = original_addresses[lhs], let right = original_addresses[rhs] else {
                return lhs < rhs
            }
            if left.root != right.root { return left.root < right.root }
            return left.descendants.lexicographicallyPrecedes(right.descendants)
        }
        let ordered_ids = original_ids + additional_ids.filter { original_addresses[$0] == nil }
        let lines: [Line] = ordered_ids.map { id in
            let states = zip(alternatives.candidates, indices).map { candidate, index in
                let node = index.entries[id]
                return CandidateState(
                    id: candidate.id,
                    label: candidate.label,
                    change: node?.entry.change,
                    entry_label: node?.entry.label,
                    before: node?.entry.before,
                    after: node?.entry.after,
                    before_address: node?.entry.before_address,
                    after_address: node?.entry.after_address,
                    before_parent_id: node?.before_parent_id,
                    after_parent_id: node?.after_parent_id
                )
            }
            return Line(
                id: id,
                label: labels[id] ?? id,
                baseline_address: original_addresses[id],
                candidates: states
            )
        }
        return .init(baseline: alternatives.baseline, lines: lines)
    }

    private static func make_index(_ difference: TreeDifference<Value>) -> Index {
        var entries: [String: TreeDifference<Value>.Entry] = [:]
        var order: [String] = []

        func visit(_ nodes: [Tree<TreeDifference<Value>.Entry>.Node]) {
            for node in nodes {
                let entry = node.value
                entries[entry.id] = entry
                order.append(entry.id)
                visit(node.children)
            }
        }
        visit(difference.tree.roots)

        var old_addresses: [TreeAddress: String] = [:]
        var new_addresses: [TreeAddress: String] = [:]
        for id in order {
            guard let entry = entries[id] else { continue }
            if let address = entry.before_address { old_addresses[address] = id }
            if let address = entry.after_address { new_addresses[address] = id }
        }
        var states: [String: NodeState] = [:]
        for id in order {
            guard let entry = entries[id] else { continue }
            states[id] = .init(
                entry: entry,
                before_parent_id: entry.before_address?.parent.flatMap { old_addresses[$0] },
                after_parent_id: entry.after_address?.parent.flatMap { new_addresses[$0] }
            )
        }
        return .init(order: order, entries: states)
    }
}

extension TreeDifferenceAlternativesLayout where Value: Equatable {
    /// Backward-compatible convenience for Equatable node payloads.
    public static func make(
        _ alternatives: DifferenceAlternatives<TreeDifference<Value>>
    ) throws -> Self {
        try make(alternatives, baseline_equivalent: ==)
    }
}

public enum TreeDifferenceAlternativesRenderer {
    /// One row per stable identity; the indent denotes original topology only.
    /// A candidate moved to another parent is reported explicitly, not reparented
    /// in a fictitious combined tree.
    public static func render<Value>(
        _ layout: TreeDifferenceAlternativesLayout<Value>,
        show_unchanged: Bool = false,
        value_text: ((Value) -> String)? = nil
    ) -> String {
        var rendered: [String] = []
        for line in layout.lines {
            let changed = line.candidates.contains { state in
                state.change != nil && state.change != .unchanged
            }
            guard changed || show_unchanged else { continue }
            let indentation = String(
                repeating: "  ",
                count: line.baseline_address?.descendants.count ?? 0
            )
            let markers = line.candidates.map { state in
                "\(state.id):\(marker(state.change))"
            }.joined(separator: ", ")
            rendered.append("\(indentation)\(line.label) [\(markers)]")
            for state in line.candidates {
                guard let change = state.change, change != .unchanged else { continue }
                if change == .moved || change == .moved_modified {
                    rendered.append("\(indentation)  \(state.id): parent \(state.before_parent_id ?? "<root>") -> \(state.after_parent_id ?? "<root>")")
                } else if line.baseline_address == nil, let parent = state.after_parent_id {
                    rendered.append("\(indentation)  \(state.id): introduced under \(parent)")
                }
                if let value_text, let after = state.after,
                   let before = state.before {
                    let original = value_text(before)
                    let replacement = value_text(after)
                    if original != replacement {
                        rendered.append("\(indentation)  \(state.id): - \(original) / + \(replacement)")
                    }
                }
            }
        }
        return rendered.joined(separator: "\n")
    }

    private static func marker(_ change: TreeChangeKind?) -> String {
        switch change {
        case nil: return "∅"
        case .unchanged: return "="
        case .added: return "+"
        case .removed: return "-"
        case .modified: return "~"
        case .moved: return ">"
        case .moved_modified: return "*"
        }
    }
}
