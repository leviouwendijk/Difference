public protocol DifferenceRendering {
    static func render(
        _ difference: TextDifference
    ) -> String
}

extension DifferenceRenderer: DifferenceRendering {
    public static func render(
        _ difference: TextDifference
    ) -> String {
        render(
            difference,
            options: .unified
        )
    }
}

extension DifferenceRenderer {
    public enum Full: DifferenceRendering {
        public static func render(
            _ difference: TextDifference
        ) -> String {
            DifferenceRenderer.render(
                difference,
                options: .full
            )
        }
    }
}
