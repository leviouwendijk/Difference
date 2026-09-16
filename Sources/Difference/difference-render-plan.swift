import ExcerptPresentation

public struct DifferenceRenderPlan: Sendable, Hashable {
    public struct Segment: Sendable, Hashable {
        public let component: DifferenceLineRenderComponent
        public let text: String

        public init(
            component: DifferenceLineRenderComponent,
            text: String
        ) {
            self.component = component
            self.text = text
        }
    }

    public struct Line: Sendable, Hashable {
        public let role: DifferenceLayout.Role
        public let segments: [Segment]
        public let componentSpacing: Int

        public init(
            role: DifferenceLayout.Role,
            segments: [Segment],
            componentSpacing: Int
        ) {
            self.role = role
            self.segments = segments
            self.componentSpacing = max(
                0,
                componentSpacing
            )
        }
    }

    public let lines: [Line]

    public init(
        lines: [Line]
    ) {
        self.lines = lines
    }

    public static func make(
        _ layout: DifferenceLayout,
        options: DifferenceRenderOptions = .unified
    ) -> Self {
        let lineNumberWidth = lineNumberWidth(
            in: layout
        )

        return .init(
            lines: layout.lines.map {
                planLine(
                    $0,
                    lineNumberWidth: lineNumberWidth,
                    options: options
                )
            }
        )
    }

    private static func planLine(
        _ line: DifferenceLayout.Line,
        lineNumberWidth: Int,
        options: DifferenceRenderOptions
    ) -> Line {
        switch line.role {
        case .headerOld:
            return .init(
                role: line.role,
                segments: [
                    .init(
                        component: .marker,
                        text: "---"
                    ),
                    .init(
                        component: .text,
                        text: line.text
                    ),
                ],
                componentSpacing: 1
            )

        case .headerNew:
            return .init(
                role: line.role,
                segments: [
                    .init(
                        component: .marker,
                        text: "+++"
                    ),
                    .init(
                        component: .text,
                        text: line.text
                    ),
                ],
                componentSpacing: 1
            )

        case .separator:
            return .init(
                role: line.role,
                segments: [
                    .init(
                        component: .text,
                        text: line.text
                    ),
                ],
                componentSpacing: 0
            )

        case .endOfFile:
            return .init(
                role: line.role,
                segments: endOfFileSegments(
                    for: line,
                    lineNumberWidth: lineNumberWidth,
                    options: options
                ),
                componentSpacing: options.componentSpacing
            )

        case .equal,
             .insert,
             .delete:
            return .init(
                role: line.role,
                segments: options.lineComponents.compactMap {
                    segment(
                        $0,
                        for: line,
                        lineNumberWidth: lineNumberWidth,
                        options: options
                    )
                },
                componentSpacing: options.componentSpacing
            )
        }
    }

    private static func segment(
        _ component: DifferenceLineRenderComponent,
        for line: DifferenceLayout.Line,
        lineNumberWidth: Int,
        options: DifferenceRenderOptions
    ) -> Segment? {
        switch component {
        case .lineNumbers:
            guard lineNumberWidth > 0 else {
                return nil
            }

            return .init(
                component: component,
                text: lineNumbers(
                    for: line,
                    width: lineNumberWidth,
                    format: options.lineNumberFormat,
                    missingCharacter: options.missingLineNumberCharacter
                )
            )

        case .marker:
            return .init(
                component: component,
                text: marker(
                    for: line.role,
                    options: options
                )
            )

        case .border:
            return .init(
                component: component,
                text: options.border
            )

        case .text:
            return .init(
                component: component,
                text: line.text
            )
        }
    }

    private static func endOfFileSegments(
        for line: DifferenceLayout.Line,
        lineNumberWidth: Int,
        options: DifferenceRenderOptions
    ) -> [Segment] {
        let gutterWidth = max(
            line.text.count,
            lineNumberGutterWidth(
                columnWidth: lineNumberWidth,
                format: options.lineNumberFormat
            )
        )
        let label = String(
            repeating: " ",
            count: max(
                0,
                gutterWidth - line.text.count
            )
        ) + line.text

        return options.lineComponents.compactMap {
            component in

            switch component {
            case .lineNumbers:
                return .init(
                    component: component,
                    text: label
                )

            case .border:
                return .init(
                    component: component,
                    text: options.border
                )

            case .marker,
                 .text:
                return nil
            }
        }
    }

    private static func marker(
        for role: DifferenceLayout.Role,
        options: DifferenceRenderOptions
    ) -> String {
        switch role {
        case .equal:
            return options.equalMarker

        case .insert:
            return options.insertMarker

        case .delete:
            return options.deleteMarker

        case .headerOld,
             .headerNew,
             .separator,
             .endOfFile:
            return ""
        }
    }

    private static func lineNumberWidth(
        in layout: DifferenceLayout
    ) -> Int {
        LinePresentation.Gutter.numberWidth(
            values: layout.lines.flatMap { line in
                [
                    line.oldLine,
                    line.newLine,
                ]
            }
        )
    }

    private static func lineNumberGutterWidth(
        columnWidth: Int,
        format: DifferenceLineNumberFormat
    ) -> Int {
        LinePresentation.Gutter(
            columns: [
                .init(
                    text: "",
                    width: columnWidth,
                    alignment: .trailing
                ),
                .init(
                    text: "",
                    width: columnWidth,
                    alignment: .trailing
                ),
            ],
            separator: gutterSeparator(
                for: format
            )
        )
        .width
    }

    private static func lineNumbers(
        for line: DifferenceLayout.Line,
        width: Int,
        format: DifferenceLineNumberFormat,
        missingCharacter: Character
    ) -> String {
        LinePresentation.Gutter(
            columns: [
                .number(
                    line.oldLine,
                    width: width,
                    missingCharacter: missingCharacter
                ),
                .number(
                    line.newLine,
                    width: width,
                    missingCharacter: missingCharacter
                ),
            ],
            separator: gutterSeparator(
                for: format
            )
        )
        .text
    }

    private static func gutterSeparator(
        for format: DifferenceLineNumberFormat
    ) -> String {
        switch format {
        case .compact:
            return ":"

        case .columns:
            return "  "
        }
    }
}
