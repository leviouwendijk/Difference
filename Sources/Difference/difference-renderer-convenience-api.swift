extension DifferenceRenderer {
    public static func layout(
        _ difference: TextDifference,
        options: DifferenceRenderOptions = .unified
    ) -> DifferenceLayout {
        DifferenceLayout.make(
            difference,
            options: options
        )
    }

    public static func render(
        _ difference: TextDifference,
        options: DifferenceRenderOptions = .unified
    ) -> String {
        Basic.render(
            difference,
            options: options
        )
    }

    public static func render(
        _ layout: DifferenceLayout,
        options: DifferenceRenderOptions = .unified
    ) -> String {
        Basic.render(
            layout,
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

    public static func plain(
        _ layout: DifferenceLayout,
        options: DifferenceRenderOptions = .unified
    ) -> String {
        Basic.plain(
            layout,
            options: options
        )
    }
}
