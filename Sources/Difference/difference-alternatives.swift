public struct DifferenceBaseline: Sendable, Codable, Hashable {
    /// Revision identity supplied by the owner of the original content.
    public let id: String
    /// Optional external fingerprint. No hashing or verification is implied here.
    public let fingerprint: String?

    public init(id: String, fingerprint: String? = nil) {
        self.id = id
        self.fingerprint = fingerprint
    }
}

public enum DifferenceAlternativesError: Error, Sendable, Equatable {
    case empty_baseline_id
    case empty_baseline_fingerprint
    case no_candidates
    case empty_candidate_id
    case empty_candidate_label(String)
    case duplicate_candidate_id(String)
    case inconsistent_baseline(String)
}

/// Independent deltas against a single baseline, not successive revisions.
/// The caller must supply genuine common-baseline deltas; prefer the typed
/// TextDiffer/TreeDiffer builders below, which construct them from one original.
public struct DifferenceAlternatives<Delta> {
    public struct Candidate {
        public let id: String
        public let label: String
        public let difference: Delta

        public init(id: String, label: String, difference: Delta) {
            self.id = id
            self.label = label
            self.difference = difference
        }
    }

    public let baseline: DifferenceBaseline
    /// Ordered, stable; use candidate IDs rather than array indices as identities.
    public let candidates: [Candidate]

    public init(baseline: DifferenceBaseline, candidates: [Candidate]) throws {
        guard !baseline.id.isEmpty else {
            throw DifferenceAlternativesError.empty_baseline_id
        }
        if let fingerprint = baseline.fingerprint, fingerprint.isEmpty {
            throw DifferenceAlternativesError.empty_baseline_fingerprint
        }
        guard !candidates.isEmpty else {
            throw DifferenceAlternativesError.no_candidates
        }
        var identifiers = Set<String>()
        for candidate in candidates {
            guard !candidate.id.isEmpty else {
                throw DifferenceAlternativesError.empty_candidate_id
            }
            guard !candidate.label.isEmpty else {
                throw DifferenceAlternativesError.empty_candidate_label(candidate.id)
            }
            guard identifiers.insert(candidate.id).inserted else {
                throw DifferenceAlternativesError.duplicate_candidate_id(candidate.id)
            }
        }
        self.baseline = baseline
        self.candidates = candidates
    }
}

extension DifferenceAlternatives.Candidate: Sendable where Delta: Sendable {}
extension DifferenceAlternatives: Sendable where Delta: Sendable {}
extension DifferenceAlternatives.Candidate: Codable where Delta: Codable {}
extension DifferenceAlternatives: Codable where Delta: Codable {}
extension DifferenceAlternatives.Candidate: Equatable where Delta: Equatable {}
extension DifferenceAlternatives: Equatable where Delta: Equatable {}
extension DifferenceAlternatives.Candidate: Hashable where Delta: Hashable {}
extension DifferenceAlternatives: Hashable where Delta: Hashable {}
