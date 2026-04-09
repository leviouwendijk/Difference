import Difference
import ANSI

extension DifferenceRenderer {
    public enum Terminal {
        public static func render(
            _ difference: TextDifference
        ) -> String {
            render(
                difference,
                options: .init()
            )
        }

        public static func render(
            _ difference: TextDifference,
            options: DifferenceTerminalRenderOptions = .init()
        ) -> String {
            let renderedLines = renderedBodyLines(
                difference.lines,
                options: options
            )

            var out: [String] = []
            out.reserveCapacity(renderedLines.count + 2)

            if options.base.showHeader {
                out.append(
                    colorize(
                        "--- \(difference.oldName)",
                        colors: options.style.headerColors
                    )
                )
                out.append(
                    colorize(
                        "+++ \(difference.newName)",
                        colors: options.style.headerColors
                    )
                )
            }

            out.append(contentsOf: renderedLines)

            return out.joined(separator: "\n")
        }

        public static func print(
            _ difference: TextDifference,
            options: DifferenceTerminalRenderOptions = .init()
        ) {
            Swift.print(
                render(
                    difference,
                    options: options
                )
            )
        }

        private static func renderedBodyLines(
            _ lines: [DifferenceLine],
            options: DifferenceTerminalRenderOptions
        ) -> [String] {
            if options.base.showUnchangedLines || options.base.contextLineCount == .max {
                return lines.map {
                    styledLine($0, options: options)
                }
            }

            let context = max(0, options.base.contextLineCount)
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
                    out.append(
                        colorize(
                            options.base.collapseSeparator,
                            colors: options.style.separatorColors
                        )
                    )
                }

                out.append(
                    styledLine(
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

        private static func styledLine(
            _ line: DifferenceLine,
            options: DifferenceTerminalRenderOptions
        ) -> String {
            switch line.operation {
            case .equal:
                return colorize(
                    options.base.equalPrefix + line.text,
                    colors: options.style.equalColors
                )

            case .insert:
                return colorize(
                    options.base.insertPrefix + line.text,
                    colors: options.style.insertColors
                )

            case .delete:
                return colorize(
                    options.base.deletePrefix + line.text,
                    colors: options.style.deleteColors
                )
            }
        }

        private static func colorize(
            _ string: String,
            colors: [ANSIColor]
        ) -> String {
            guard !colors.isEmpty else {
                return string
            }

            let prefix = colors.map(\.rawValue).joined()
            return "\(prefix)\(string)\(ANSIColor.reset.rawValue)"
        }
    }

    public enum ANSI: DifferenceRendering {
        public static func render(
            _ difference: TextDifference
        ) -> String {
            Terminal.render(difference)
        }
    }
}
