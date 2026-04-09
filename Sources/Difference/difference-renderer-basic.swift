extension DifferenceRenderer {
    public enum Basic {
        public static func render(
            _ difference: TextDifference,
            options: DifferenceRenderOptions = .unified
        ) -> String {
            let renderedLines = renderedBodyLines(
                difference.lines,
                options: options
            )

            var out: [String] = []
            out.reserveCapacity(renderedLines.count + 2)

            if options.showHeader {
                out.append("--- \(difference.oldName)")
                out.append("+++ \(difference.newName)")
            }

            out.append(contentsOf: renderedLines)

            return out.joined(separator: "\n")
        }

        public static func plain(
            _ difference: TextDifference,
            options: DifferenceRenderOptions = .unified
        ) -> String {
            render(
                difference,
                options: options
            )
        }

        private static func renderedBodyLines(
            _ lines: [DifferenceLine],
            options: DifferenceRenderOptions
        ) -> [String] {
            guard !lines.isEmpty else {
                return []
            }

            if options.showUnchangedLines || options.contextLineCount == .max {
                return lines.map {
                    prefixedLine($0, options: options)
                }
            }

            let context = max(0, options.contextLineCount)
            let indicesToShow = visibleLineIndices(
                lines: lines,
                contextLineCount: context
            )

            guard !indicesToShow.isEmpty else {
                return []
            }

            var out: [String] = []
            var previousIndex: Int?

            for index in indicesToShow.sorted() {
                if let previousIndex,
                   index > previousIndex + 1 {
                    out.append(options.collapseSeparator)
                }

                out.append(
                    prefixedLine(
                        lines[index],
                        options: options
                    )
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

        private static func prefixedLine(
            _ line: DifferenceLine,
            options: DifferenceRenderOptions
        ) -> String {
            switch line.operation {
            case .equal:
                return options.equalPrefix + line.text

            case .insert:
                return options.insertPrefix + line.text

            case .delete:
                return options.deletePrefix + line.text
            }
        }
    }
}
