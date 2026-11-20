import Difference

enum DifferenceAlignmentReuseSmoke {
    static func run() {
        let ambiguous = TextDifference(
            oldName: "old.swift", newName: "new.swift",
            lines: [
                .init(operation: .equal, text: "start", oldLine: 1, newLine: 1),
                .init(operation: .delete, text: "configure(timeout: 30)", oldLine: 2),
                .init(operation: .delete, text: "configure(retries: 2)", oldLine: 3),
                .init(operation: .insert, text: "configure(retries: 4)", newLine: 2),
                .init(operation: .equal, text: "middle A", oldLine: 4, newLine: 3),
                .init(operation: .equal, text: "middle B", oldLine: 5, newLine: 4),
                .init(operation: .delete, text: "let 東京 = 30", oldLine: 6),
                .init(operation: .insert, text: "let 東京 = 45", newLine: 5),
                .init(operation: .equal, text: "end", oldLine: 7, newLine: 6)
            ]
        )
        let fixtures = [
            ambiguous,
            TextDiffer.diff(old: "", new: "new\n"),
            TextDiffer.diff(old: "same\n", new: "same\n"),
            TextDiffer.diff(old: "🇯🇵 日本語\nend", new: "🇯🇵 漢字\nend"),
            TextDiffer.diff(old: "A\nB\nC\n", new: "A\nX\nY\nC\n")
        ]
        let policies: [DifferenceLayout.Pairing] = [
            .none,
            .similarity(minimum: 0.45),
            .aligned(minimum: 0.45),
            .aligned(minimum: 0.45, maxCells: 1)
        ]
        let full = DifferenceRenderOptions.full
        let hunks = DifferenceRenderOptions(
            showHeader: true, showUnchangedLines: false,
            contextLineCount: 0, showHunkHeaders: true
        )
        for difference in fixtures {
            for pairing in policies {
                let analysis = difference.analyze(options: .init(pairing: pairing, inline: .characters))
                let noInline = difference.analyze(options: .init(pairing: pairing, inline: .none))
                precondition(analysis.alignments == noInline.alignments,
                             "alignment decisions must not depend on inline analysis")
                var visited = Set<Int>()
                for alignment in analysis.alignments {
                    precondition(!alignment.range.isEmpty)
                    var covered: [Int] = []
                    for step in alignment.steps {
                        precondition(step.oldIndex != nil || step.newIndex != nil)
                        if let old = step.oldIndex {
                            precondition(alignment.range.contains(old) &&
                                         difference.lines[old].operation == .delete)
                            covered.append(old)
                            precondition(visited.insert(old).inserted)
                        }
                        if let new = step.newIndex {
                            precondition(alignment.range.contains(new) &&
                                         difference.lines[new].operation == .insert)
                            covered.append(new)
                            precondition(visited.insert(new).inserted)
                        }
                    }
                    precondition(covered.sorted() == Array(alignment.range))
                }
                let changed = difference.lines.indices.filter {
                    difference.lines[$0].operation != .equal
                }
                precondition(visited == Set(changed), "all changed lines must be represented once")

                for options in [full, hunks] {
                    let fromRaw = DifferenceLayout.project(
                        difference, mode: .split, options: options, pairing: pairing
                    )
                    let precomputed = DifferenceLayout.project(
                        noInline, mode: .split, options: options
                    )
                    precondition(fromRaw == precomputed,
                                 "direct split and cached analysis projections disagree")
                    let annotated = DifferenceLayout.project(
                        analysis, mode: .split, options: options
                    )
                    precondition(annotated.rows.count == precomputed.rows.count)
                    for (left, right) in zip(annotated.rows, precomputed.rows) {
                        precondition(left.kind == right.kind &&
                                     left.old?.line == right.old?.line &&
                                     left.new?.line == right.new?.line &&
                                     left.old?.text == right.old?.text &&
                                     left.new?.text == right.new?.text)
                    }
                    if options.showUnchangedLines {
                        let old = annotated.rows.compactMap { $0.old?.text }
                        let new = annotated.rows.compactMap { $0.new?.text }
                        precondition(old == difference.lines.filter {
                            $0.operation != .insert
                        }.map(\.text))
                        precondition(new == difference.lines.filter {
                            $0.operation != .delete
                        }.map(\.text))
                    }
                    let directUnified = DifferenceLayout.project(
                        difference, mode: .unified, options: options, pairing: pairing
                    )
                    let cachedUnified = DifferenceLayout.project(
                        noInline, mode: .unified, options: options
                    )
                    precondition(directUnified == cachedUnified,
                                 "unified layout should remain independent of pairing policy")
                }
            }
        }
        print("difference alignment reuse smoke passed")
    }
}
