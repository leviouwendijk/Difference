import ExcerptPresentation

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
            render(
                DifferenceRenderPlan.make(
                    layout,
                    options: options
                )
            )
        }

        public static func render(
            _ plan: DifferenceRenderPlan
        ) -> String {
            let rows = plan.lines.map { line in
                LinePresentation.Row(
                    segments: line.segments.map { segment in
                        .init(
                            text: segment.text
                        )
                    },
                    componentSpacing: line.componentSpacing
                )
            }

            return LinePresentation.Basic.render(
                rows
            )
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
    }
}
