#if canImport(SwiftUI)
import Difference
import SwiftUI

/// A text difference drawn from its render plan, the same plan the terminal
/// and plain renderers draw: one row per line, inserted and deleted lines
/// tinted, line numbers and gutters secondary, text monospaced and selectable.
@available(macOS 13, iOS 16, *)
public struct DifferenceView: View {
    private let plan: DifferenceRenderPlan

    public init(
        _ plan: DifferenceRenderPlan
    ) {
        self.plan = plan
    }

    public init(
        _ layout: DifferenceLayout,
        options: DifferenceRenderOptions = .unified
    ) {
        self.init(
            DifferenceRenderPlan.make(
                layout,
                options: options
            )
        )
    }

    public init(
        _ difference: TextDifference,
        options: DifferenceRenderOptions = .unified
    ) {
        self.init(
            DifferenceLayout.make(
                difference,
                options: options
            ),
            options: options
        )
    }

    public var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(plan.lines.enumerated()), id: \.offset) { _, line in
                Text(Self.text(line))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .background(Self.background(line.role))
            }
        }
        .font(.system(.caption, design: .monospaced))
        .textSelection(.enabled)
    }

    private static func text(
        _ line: DifferenceRenderPlan.Line
    ) -> AttributedString {
        var text = AttributedString()
        let spacing = String(repeating: " ", count: line.componentSpacing)
        for (index, segment) in line.segments.enumerated() {
            if index > 0 {
                text += AttributedString(spacing)
            }
            var part = AttributedString(segment.text)
            part.foregroundColor = color(segment.component, role: line.role)
            text += part
        }
        return text
    }

    private static func color(
        _ component: DifferenceLineRenderComponent,
        role: DifferenceLayout.Role
    ) -> Color {
        switch component {
        case .bar, .lineNumbers, .border:
            return .secondary
        case .marker:
            return roleColor(role) ?? .secondary
        case .text:
            switch role {
            case .headerOld, .headerNew, .separator, .endOfFile:
                return .secondary
            case .equal, .insert, .delete:
                return .primary
            }
        }
    }

    private static func roleColor(
        _ role: DifferenceLayout.Role
    ) -> Color? {
        switch role {
        case .insert: return .green
        case .delete: return .red
        case .headerOld, .headerNew, .equal, .separator, .endOfFile: return nil
        }
    }

    private static func background(
        _ role: DifferenceLayout.Role
    ) -> Color {
        roleColor(role)?.opacity(0.12) ?? .clear
    }
}

/// A tree difference (files and folders, symbols) drawn from its render
/// plan, each line coloured by what happened to it.
@available(macOS 13, iOS 16, *)
public struct TreeDifferenceView: View {
    private let plan: TreeDifferenceRenderPlan

    public init(
        _ plan: TreeDifferenceRenderPlan
    ) {
        self.plan = plan
    }

    public init(
        _ layout: TreeDifferenceLayout
    ) {
        self.init(.make(layout))
    }

    public var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(plan.lines.enumerated()), id: \.offset) { _, line in
                Text(Self.text(line))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
        .font(.system(.caption, design: .monospaced))
        .textSelection(.enabled)
    }

    private static func text(
        _ line: TreeDifferenceRenderPlan.Line
    ) -> AttributedString {
        // Spaced as TreeDifferenceRenderer joins them: the marker, then the rest.
        let spaced = line.segments.count >= 3
        var text = AttributedString()
        for (index, segment) in line.segments.enumerated() {
            var part = AttributedString((spaced && index == 1 ? " " : "") + segment.text)
            part.foregroundColor = color(segment.component, change: line.change)
            text += part
        }
        return text
    }

    private static func color(
        _ component: TreeDifferenceRenderPlan.Segment.Component,
        change: TreeChangeKind
    ) -> Color {
        switch component {
        case .marker, .label:
            return changeColor(change)
        case .branch, .relocation_separator, .movement_delimiter, .movement_reason:
            return .secondary
        case .relocation_from, .relocation_to:
            return .blue
        }
    }

    private static func changeColor(
        _ change: TreeChangeKind
    ) -> Color {
        switch change {
        case .unchanged: return .primary
        case .added: return .green
        case .removed: return .red
        case .modified: return .orange
        case .moved: return .blue
        case .moved_modified: return .purple
        }
    }
}
#endif
