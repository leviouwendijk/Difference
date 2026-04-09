extension DifferenceLayout {
    public static func make(
        _ difference: TextDifference,
        options: DifferenceRenderOptions = .unified
    ) -> Self {
        var out: [Line] = []

        if options.showHeader {
            out.append(
                .init(
                    role: .headerOld,
                    text: difference.oldName
                )
            )
            out.append(
                .init(
                    role: .headerNew,
                    text: difference.newName
                )
            )
        }

        let body = bodyLines(
            difference.lines,
            options: options
        )

        out.append(contentsOf: body)

        return .init(lines: out)
    }

    private static func bodyLines(
        _ lines: [DifferenceLine],
        options: DifferenceRenderOptions
    ) -> [Line] {
        guard !lines.isEmpty else {
            return []
        }

        if options.showUnchangedLines || options.contextLineCount == .max {
            return lines.map(layoutLine)
        }

        let context = max(0, options.contextLineCount)
        let indicesToShow = visibleLineIndices(
            lines: lines,
            contextLineCount: context
        )

        guard !indicesToShow.isEmpty else {
            return []
        }

        var out: [Line] = []
        var previousIndex: Int?

        for index in indicesToShow.sorted() {
            if let previousIndex,
               index > previousIndex + 1 {
                out.append(
                    .init(
                        role: .separator,
                        text: options.collapseSeparator
                    )
                )
            }

            out.append(
                layoutLine(lines[index])
            )

            previousIndex = index
        }

        return out
    }

    private static func visibleLineIndices(
        lines: [DifferenceLine],
        contextLineCount: Int
    ) -> Set<Int> {
        var visible: Set<Int> = []

        for (index, line) in lines.enumerated() {
            guard line.operation != .equal else {
                continue
            }

            let lowerBound = max(0, index - contextLineCount)
            let upperBound = min(lines.count - 1, index + contextLineCount)

            for visibleIndex in lowerBound...upperBound {
                visible.insert(visibleIndex)
            }
        }

        return visible
    }

    private static func layoutLine(
        _ line: DifferenceLine
    ) -> Line {
        switch line.operation {
        case .equal:
            return .init(
                role: .equal,
                text: line.text
            )

        case .insert:
            return .init(
                role: .insert,
                text: line.text
            )

        case .delete:
            return .init(
                role: .delete,
                text: line.text
            )
        }
    }
}
