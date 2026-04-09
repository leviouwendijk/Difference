extension DifferenceRenderer {
    public enum Basic {
        public static func render(
            _ difference: TextDifference
        ) -> String {
            render(
                difference,
                options: .unified
            )
        }

        public static func render(
            _ difference: TextDifference,
            options: DifferenceRenderOptions = .unified
        ) -> String {
            render(
                DifferenceLayout.make(
                    difference,
                    options: options
                ),
                options: options
            )
        }

        public static func render(
            _ layout: DifferenceLayout,
            options: DifferenceRenderOptions = .unified
        ) -> String {
            layout.lines
                .map { renderLine($0, options: options) }
                .joined(separator: "\n")
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

        public static func plain(
            _ layout: DifferenceLayout,
            options: DifferenceRenderOptions = .unified
        ) -> String {
            render(
                layout,
                options: options
            )
        }

        private static func renderLine(
            _ line: DifferenceLayout.Line,
            options: DifferenceRenderOptions
        ) -> String {
            switch line.role {
            case .headerOld:
                return "--- \(line.text)"

            case .headerNew:
                return "+++ \(line.text)"

            case .equal:
                return options.equalPrefix + line.text

            case .insert:
                return options.insertPrefix + line.text

            case .delete:
                return options.deletePrefix + line.text

            case .separator:
                return line.text
            }
        }
    }
}
