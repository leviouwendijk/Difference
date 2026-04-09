extension DifferenceRenderer {
    public static func render(
        _ difference: TextDifference,
        options: DifferenceRenderOptions = .unified
    ) -> String {
        Basic.render(
            difference,
            options: options
        )
    }

    public static func plain(
        _ difference: TextDifference,
        options: DifferenceRenderOptions = .unified
    ) -> String {
        Basic.plain(
            difference,
            options: options
        )
    }
}
