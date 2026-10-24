import Difference
import Primitives

private struct AlternativeNodeValue: Equatable, Sendable {
    let id: String
    let name: String
}

private func alternative_node(
    _ id: String,
    _ name: String? = nil,
    _ children: [Tree<AlternativeNodeValue>.Node] = []
) -> Tree<AlternativeNodeValue>.Node {
    .init(.init(id: id, name: name ?? id), children: children)
}

func differenceAlternativesMaintainIndependentCandidates() throws {
    let baseline = DifferenceBaseline(id: "baseline", fingerprint: "provided-by-caller")
    let alternatives = try TextDiffer.diff_alternatives(
        old: "start\nold\nend\n",
        baseline: baseline,
        candidates: [
            .init(id: "A", label: "first", new: "start\nnew A\nend\n"),
            .init(id: "B", label: "second", new: "start\nnew B\nend\n"),
            .init(id: "C", label: "third", new: "prefix\nstart\nold\nend\n"),
        ]
    )
    try expect(
        alternatives.candidates.map(\.id) == ["A", "B", "C"],
        "candidate identities retain caller-supplied order"
    )
    let layout = try TextDifferenceAlternativesLayout.make(alternatives)
    let result = TextDifferenceAlternativesRenderer.render(layout)
    try expect(result.contains("-[A,B] old"), "both deletions align to the old line")
    try expect(result.contains("+[A] new A"), "A replacement preserved")
    try expect(result.contains("+[B] new B"), "B replacement preserved")
    try expect(result.contains("+[C] prefix"), "leading insertion preserved")

    do {
        _ = try DifferenceAlternatives<Int>(
            baseline: baseline,
            candidates: [
                .init(id: "A", label: "first", difference: 1),
                .init(id: "A", label: "second", difference: 2),
            ]
        )
        throw RegressionFailure.assertion("duplicate candidate id must fail")
    } catch DifferenceAlternativesError.duplicate_candidate_id("A") {
        // Expected.
    }

    let different_baseline = try DifferenceAlternatives<TextDifference>(
        baseline: baseline,
        candidates: [
            .init(id: "A", label: "A", difference: TextDiffer.diff(old: "one", new: "new")),
            .init(id: "B", label: "B", difference: TextDiffer.diff(old: "two", new: "new")),
        ]
    )
    do {
        _ = try TextDifferenceAlternativesLayout.make(different_baseline)
        throw RegressionFailure.assertion("inconsistent original text must fail")
    } catch DifferenceAlternativesError.inconsistent_baseline("baseline") {
        // Expected.
    }
}

func treeDifferenceAlternativesKeepCandidateTopology() throws {
    let baseline = DifferenceBaseline(id: "base")
    let before = Tree<AlternativeNodeValue>(roots: [alternative_node("R", "root", [
        alternative_node("X", "X", [alternative_node("M", "moved")]),
        alternative_node("Y", "Y", [alternative_node("K", "keep")]),
    ])])
    let after_a = Tree<AlternativeNodeValue>(roots: [alternative_node("R", "root", [
        alternative_node("X", "X"),
        alternative_node("Y", "Y", [
            alternative_node("K", "keep"),
            alternative_node("M", "moved"),
        ]),
    ])])
    let after_b = Tree<AlternativeNodeValue>(roots: [alternative_node("R", "root", [
        alternative_node("X", "X", [
            alternative_node("M", "moved"),
            alternative_node("Z", "new"),
        ]),
        alternative_node("Y", "Y", [alternative_node("K", "keep")]),
    ])])
    let alternatives = try TreeDiffer.make_alternatives(
        before: before,
        baseline: baseline,
        candidates: [
            .init(id: "A", label: "move", after: after_a),
            .init(id: "B", label: "add", after: after_b),
        ],
        identity: { $0.id },
        label: { $0.name },
        equivalent: { $0 == $1 }
    )
    let layout = try TreeDifferenceAlternativesLayout.make(alternatives)
    guard let moved = layout.lines.first(where: { $0.id == "M" }),
          let added = layout.lines.first(where: { $0.id == "Z" }) else {
        throw RegressionFailure.assertion("expected tree identities missing")
    }
    try expect(moved.candidates[0].change == .moved, "A must preserve moved status")
    try expect(moved.candidates[0].before_parent_id == "X", "old parent is X")
    try expect(moved.candidates[0].after_parent_id == "Y", "new parent is Y")
    try expect(moved.candidates[1].change == .unchanged, "B retains original placement")
    try expect(added.candidates[0].change == nil, "Z is absent from A, not removed")
    try expect(added.candidates[1].change == .added, "Z is added in B")
    let render = TreeDifferenceAlternativesRenderer.render(layout)
    try expect(render.contains("parent X -> Y"), "move rendered with distinct parents")
}
