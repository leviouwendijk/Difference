import Difference
import ANSI

@available(*, deprecated, message: "Use TerminalDifferenceRenderer from the Terminal package.")
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
            render(
                DifferenceLayout.make(
                    difference,
                    options: options.base
                ),
                options: options
            )
        }

        public static func render(
            _ layout: DifferenceLayout,
            options: DifferenceTerminalRenderOptions = .init()
        ) -> String {
            layout.lines
                .map { renderLine($0, options: options) }
                .joined(separator: "\n")
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

        public static func print(
            _ layout: DifferenceLayout,
            options: DifferenceTerminalRenderOptions = .init()
        ) {
            Swift.print(
                render(
                    layout,
                    options: options
                )
            )
        }

        private static func renderLine(
            _ line: DifferenceLayout.Line,
            options: DifferenceTerminalRenderOptions
        ) -> String {
            switch line.role {
            case .headerOld:
                return colorize(
                    "--- \(line.text)",
                    colors: options.style.headerColors
                )

            case .headerNew:
                return colorize(
                    "+++ \(line.text)",
                    colors: options.style.headerColors
                )

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

            case .separator:
                return colorize(
                    line.text,
                    colors: options.style.separatorColors
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
