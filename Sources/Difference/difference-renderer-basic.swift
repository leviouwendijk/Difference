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
            plan.lines
                .map {
                    let spacing = String(
                        repeating: " ",
                        count: $0.componentSpacing
                    )

                    return $0.segments
                        .map(\.text)
                        .joined(
                            separator: spacing
                        )
                }
                .joined(
                    separator: "\n"
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
