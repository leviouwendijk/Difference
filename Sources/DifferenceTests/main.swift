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
                coordinate: .init(
                    new: 12
                )
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
                coordinate: .init(
                    new: 1
                )
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

func differenceLayoutExposesChanges() throws {
    let layout = DifferenceLayout(
        lines: [
            .init(
                role: .headerOld,
                text: "old"
            ),
            .init(
                role: .headerNew,
                text: "new"
            ),
            .init(
                role: .equal,
                text: "unchanged",
                coordinate: .init(
                    old: 1,
                    new: 1
                )
            ),
            .init(
                role: .delete,
                text: "old value",
                coordinate: .init(
                    old: 2
                )
            ),
            .init(
                role: .insert,
                text: "new value",
                coordinate: .init(
                    new: 2
                )
            ),
            .init(
                role: .insert,
                text: "another value",
                coordinate: .init(
                    new: 3
                )
            ),
            .init(
                role: .separator,
                text: " ..."
            ),
            .init(
                role: .endOfFile,
                text: "EOF"
            ),
        ]
    )

    try expect(
        layout.changes.count == 3,
        "changes contains only inserted and deleted lines"
    )
    try expect(
        layout.changes.lines.map(\.role) == [
            .delete,
            .insert,
            .insert,
        ],
        "changes preserves changed-line ordering"
    )
    try expect(
        layout.changes.coordinates == [
            .init(
                old: 2
            ),
            .init(
                new: 2
            ),
            .init(
                new: 3
            ),
        ],
        "changes exposes changed-line coordinates"
    )

    try expect(
        layout.changes.insertions.count == 2,
        "insertions reports inserted-line count"
    )
    try expect(
        layout.changes.insertions.lines.map(\.text) == [
            "new value",
            "another value",
        ],
        "insertions exposes inserted lines"
    )
    try expect(
        layout.changes.insertions.coordinates == [
            .init(
                new: 2
            ),
            .init(
                new: 3
            ),
        ],
        "insertions exposes new-side coordinates"
    )
    try expect(
        !layout.changes.insertions.isEmpty,
        "insertions reports itself as non-empty"
    )

    try expect(
        layout.changes.deletions.count == 1,
        "deletions reports deleted-line count"
    )
    try expect(
        layout.changes.deletions.lines.map(\.text) == [
            "old value",
        ],
        "deletions exposes deleted lines"
    )
    try expect(
        layout.changes.deletions.coordinates == [
            .init(
                old: 2
            ),
        ],
        "deletions exposes old-side coordinates"
    )
    try expect(
        !layout.changes.deletions.isEmpty,
        "deletions reports itself as non-empty"
    )

    try expect(
        layout.hasChanges,
        "layout reports when changes are present"
    )
    try expect(
        !layout.changes.isEmpty,
        "changes reports itself as non-empty"
    )
    try expect(
        !layout.isEmpty,
        "layout containing lines is not empty"
    )
}

func emptyDifferenceLayoutExposesNoChanges() throws {
    let layout = DifferenceLayout(
        lines: []
    )

    try expect(
        layout.changes.count == 0,
        "empty layout has no changes"
    )
    try expect(
        layout.changes.lines.isEmpty,
        "empty layout exposes no changed lines"
    )
    try expect(
        layout.changes.coordinates.isEmpty,
        "empty layout exposes no changed coordinates"
    )

    try expect(
        layout.changes.insertions.count == 0,
        "empty layout has no insertions"
    )
    try expect(
        layout.changes.insertions.lines.isEmpty,
        "empty layout exposes no inserted lines"
    )
    try expect(
        layout.changes.insertions.coordinates.isEmpty,
        "empty layout exposes no insertion coordinates"
    )
    try expect(
        layout.changes.insertions.isEmpty,
        "empty insertion selection reports itself as empty"
    )

    try expect(
        layout.changes.deletions.count == 0,
        "empty layout has no deletions"
    )
    try expect(
        layout.changes.deletions.lines.isEmpty,
        "empty layout exposes no deleted lines"
    )
    try expect(
        layout.changes.deletions.coordinates.isEmpty,
        "empty layout exposes no deletion coordinates"
    )
    try expect(
        layout.changes.deletions.isEmpty,
        "empty deletion selection reports itself as empty"
    )

    try expect(
        !layout.hasChanges,
        "empty layout reports no changes"
    )
    try expect(
        layout.changes.isEmpty,
        "empty changes view reports itself as empty"
    )
    try expect(
        layout.isEmpty,
        "empty layout reports itself as empty"
    )
}

try basicRendererPreservesLegacyPlanRendering()
try differenceLineNumberGuttersRemainCompatible()
try differenceRenderComponentsRemainSelectable()
try differencePresetsRemainAvailable()
try differenceLayoutExposesChanges()
try emptyDifferenceLayoutExposesNoChanges()
print("DifferenceTests: passed")
