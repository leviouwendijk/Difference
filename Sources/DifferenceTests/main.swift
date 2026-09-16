import Difference

enum RegressionFailure: Error {
    case assertion(String)
}

func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) throws {
    guard condition() else {
        throw RegressionFailure.assertion(
            message
        )
    }
}

func basicRendererPreservesLegacyPlanRendering() throws {
    let plan = DifferenceRenderPlan(
        lines: [
            .init(
                role: .equal,
                segments: [
                    .init(
                        component: .marker,
                        text: " "
                    ),
                    .init(
                        component: .text,
                        text: "unchanged"
                    ),
                ],
                componentSpacing: 1
            ),
            .init(
                role: .insert,
                segments: [
                    .init(
                        component: .marker,
                        text: "+"
                    ),
                    .init(
                        component: .text,
                        text: "inserted"
                    ),
                ],
                componentSpacing: 1
            ),
        ]
    )
    let expected = plan.lines
        .map { line in
            let spacing = String(
                repeating: " ",
                count: line.componentSpacing
            )

            return line.segments
                .map(\.text)
                .joined(
                    separator: spacing
                )
        }
        .joined(
            separator: "\n"
        )

    try expect(
        DifferenceRenderer.Basic.render(
            plan
        ) == expected,
        "basic renderer must preserve legacy plan output"
    )
}

func differenceLineNumberGuttersRemainCompatible() throws {
    let layout = DifferenceLayout(
        lines: [
            .init(
                role: .insert,
                text: "value",
                oldLine: nil,
                newLine: 12
            ),
        ]
    )
    let compact = DifferenceRenderPlan.make(
        layout,
        options: .init(
            showHeader: false,
            lineComponents: [
                .lineNumbers,
            ],
            lineNumberFormat: .compact
        )
    )
    let columns = DifferenceRenderPlan.make(
        layout,
        options: .init(
            showHeader: false,
            lineComponents: [
                .lineNumbers,
            ],
            lineNumberFormat: .columns
        )
    )

    try expect(
        compact.lines[0].segments[0].text == "--:12",
        "compact line-number gutter compatibility"
    )
    try expect(
        columns.lines[0].segments[0].text == "--  12",
        "column line-number gutter compatibility"
    )
}

func differenceRenderComponentsRemainSelectable() throws {
    let layout = DifferenceLayout(
        lines: [
            .init(
                role: .insert,
                text: "value",
                oldLine: nil,
                newLine: 1
            ),
        ]
    )
    let markerAndText = DifferenceRenderPlan.make(
        layout,
        options: .init(
            showHeader: false,
            lineComponents: [
                .marker,
                .text,
            ]
        )
    )
    let borderOnly = DifferenceRenderPlan.make(
        layout,
        options: .init(
            showHeader: false,
            lineComponents: [
                .border,
            ],
            border: "│"
        )
    )

    try expect(
        markerAndText.lines[0].segments.map(\.component) == [
            .marker,
            .text,
        ],
        "marker and text components remain selectable"
    )
    try expect(
        markerAndText.lines[0].segments.map(\.text) == [
            "+",
            "value",
        ],
        "selected marker and text preserve values"
    )
    try expect(
        borderOnly.lines[0].segments.map(\.component) == [
            .border,
        ],
        "border component remains independently selectable"
    )
    try expect(
        borderOnly.lines[0].segments[0].text == "│",
        "custom border remains configurable"
    )
}

func differencePresetsRemainAvailable() throws {
    try expect(
        DifferenceRenderOptions.unified.lineComponents == [
            .lineNumbers,
            .border,
            .marker,
            .text,
        ],
        "unified preset preserves component ordering"
    )
    try expect(
        DifferenceRenderOptions.prefixedUnified.lineComponents == [
            .marker,
            .text,
        ],
        "prefixed unified preset preserves component selection"
    )
    try expect(
        DifferenceRenderOptions.prefixedFull.showUnchangedLines,
        "prefixed full preset remains full"
    )
}

try basicRendererPreservesLegacyPlanRendering()
try differenceLineNumberGuttersRemainCompatible()
try differenceRenderComponentsRemainSelectable()
try differencePresetsRemainAvailable()
print("DifferenceTests: passed")
