public struct TextAlternative: Sendable, Codable, Hashable {
    public let id: String
    public let label: String
    public let new: String

    public init(id: String, label: String, new: String) {
        self.id = id
        self.label = label
        self.new = new
    }
}

extension TextDiffer {
    /// Each candidate is compared with the same original source string.
    public static func diff_alternatives(
        old: String,
        baseline: DifferenceBaseline,
        candidates: [TextAlternative]
    ) throws -> DifferenceAlternatives<TextDifference> {
        try .init(
            baseline: baseline,
            candidates: candidates.map { candidate in
                .init(
                    id: candidate.id,
                    label: candidate.label,
                    difference: diff(
                        old: old,
                        new: candidate.new,
                        oldName: baseline.id,
                        newName: candidate.label
                    )
                )
            }
        )
    }
}

/// Multi-candidate text overlay aligned to original lines/gaps. Insertions are
/// associated with the last encountered baseline line (0 = before first line).
/// It does not claim individual inserted lines are pairwise aligned or mergeable.
public struct TextDifferenceAlternativesLayout: Sendable, Codable, Hashable {
    public struct InsertedLine: Sendable, Codable, Hashable {
        public let new_line: Int
        public let text: String
    }

    public struct CandidateState: Sendable, Codable, Hashable {
        public let id: String
        public let label: String
        public let deletes_original: Bool
        public let insertions: [InsertedLine]
    }

    public struct Line: Sendable, Codable, Hashable {
        /// Nil is the gap before baseline line 1.
        public let old_line: Int?
        public let old_text: String?
        public let candidates: [CandidateState]

        public var has_changes: Bool {
            candidates.contains { $0.deletes_original || !$0.insertions.isEmpty }
        }
    }

    public let baseline: DifferenceBaseline
    public let lines: [Line]

    private struct IndexedCandidate {
        let originals: [Int: String]
        let deletions: Set<Int>
        let insertions_after: [Int: [InsertedLine]]
    }

    public static func make(
        _ alternatives: DifferenceAlternatives<TextDifference>
    ) throws -> Self {
        let indexed = alternatives.candidates.map { index($0.difference) }
        guard let original = indexed.first?.originals else {
            throw DifferenceAlternativesError.no_candidates
        }
        for candidate in indexed.dropFirst() {
            guard candidate.originals == original else {
                throw DifferenceAlternativesError.inconsistent_baseline(alternatives.baseline.id)
            }
        }
        let numbers = original.keys.sorted()
        var rows: [Line] = []
        let has_initial_insertions = indexed.contains { !($0.insertions_after[0] ?? []).isEmpty }
        if has_initial_insertions {
            rows.append(.init(
                old_line: nil,
                old_text: nil,
                candidates: zip(alternatives.candidates, indexed).map { candidate, index in
                    .init(
                        id: candidate.id,
                        label: candidate.label,
                        deletes_original: false,
                        insertions: index.insertions_after[0] ?? []
                    )
                }
            ))
        }
        for number in numbers {
            rows.append(.init(
                old_line: number,
                old_text: original[number],
                candidates: zip(alternatives.candidates, indexed).map { candidate, index in
                    .init(
                        id: candidate.id,
                        label: candidate.label,
                        deletes_original: index.deletions.contains(number),
                        insertions: index.insertions_after[number] ?? []
                    )
                }
            ))
        }
        return .init(baseline: alternatives.baseline, lines: rows)
    }

    private static func index(_ difference: TextDifference) -> IndexedCandidate {
        var original: [Int: String] = [:]
        var deletions = Set<Int>()
        var insertions: [Int: [InsertedLine]] = [:]
        var previous_original_line = 0
        for line in difference.lines {
            switch line.operation {
            case .equal, .delete:
                guard let number = line.oldLine else { continue }
                original[number] = line.text
                if line.operation == .delete { deletions.insert(number) }
                previous_original_line = number
            case .insert:
                guard let number = line.newLine else { continue }
                insertions[previous_original_line, default: []].append(
                    .init(new_line: number, text: line.text)
                )
            }
        }
        return .init(
            originals: original,
            deletions: deletions,
            insertions_after: insertions
        )
    }
}

public enum TextDifferenceAlternativesRenderer {
    public static func render(
        _ layout: TextDifferenceAlternativesLayout,
        show_unchanged: Bool = false
    ) -> String {
        var lines: [String] = []
        for row in layout.lines {
            guard row.has_changes || show_unchanged else { continue }
            if let old_text = row.old_text {
                let removed_by = row.candidates
                    .filter(\.deletes_original)
                    .map(\.id)
                let marker = removed_by.isEmpty
                    ? "  "
                    : "-[\(removed_by.joined(separator: ","))]"
                lines.append("\(marker) \(old_text)")
            }
            for candidate in row.candidates {
                for inserted in candidate.insertions {
                    lines.append("+[\(candidate.id)] \(inserted.text)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}
