import Difference

@main
struct DifferenceInlineTests {
    enum Failure: Error { case mismatch }

    static func main() throws {
        let difference = TextDiffer.diff(
            old: "let timeout = 30; retries = 2\n",
            new: "let timeout = 45; retries = 4\n"
        )
        let analysis = difference.analyze(options: .init(
            pairing: .similarity(minimum: 0.3), inline: .characters
        ))
        guard analysis.pairs.count == 1,
              analysis.pairs[0].old.count >= 2,
              analysis.pairs[0].new.count >= 2,
              analysis.pairs[0].old.allSatisfy({ $0.range.start.column < $0.range.end.column }) else {
            throw Failure.mismatch
        }
        let split = DifferenceLayout.project(analysis, mode: .split, options: .full)
        let unified = DifferenceLayout.project(analysis, mode: .unified, options: .full)
        guard split.rows.contains(where: { ($0.old?.spans.count ?? 0) >= 2 }),
              unified.rows.contains(where: { ($0.new?.spans.count ?? 0) >= 2 }) else {
            throw Failure.mismatch
        }

        let before = "let place = \"日本語東京\"\n"
        let after = "let place = \"日本語大阪\"\n"
        let unicode = TextDiffer.diff(old: before, new: after).analyze(options: .init(
            pairing: .similarity(minimum: 0.3), inline: .characters
        ))
        let expected = "let place = \"日本語".utf8.count + 1
        guard unicode.pairs.count == 1,
              unicode.pairs[0].old.first?.range.start.column == expected,
              unicode.pairs[0].new.first?.range.start.column == expected else {
            throw Failure.mismatch
        }
        let coarse = difference.analyze(options: .init(
            pairing: .similarity(minimum: 0.3), inline: .characters, maxCells: 1
        ))
        guard coarse.pairs.count == 1, !coarse.pairs[0].old.isEmpty else {
            throw Failure.mismatch
        }
        guard difference.analyze(options: .init(pairing: .none)).pairs.isEmpty else {
            throw Failure.mismatch
        }
        print("difference inline analysis passed")
    }
}
