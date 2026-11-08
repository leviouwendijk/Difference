public extension TextDifference {
    struct Hunk: Sendable, Codable, Hashable {
        /// Half-open indices into TextDifference.lines.
        public let indices: Range<Int>
        public let oldStart: Int
        public let oldCount: Int
        public let newStart: Int
        public let newCount: Int

        public var header: String {
            "@@ -\(oldStart),\(oldCount) +\(newStart),\(newCount) @@"
        }
    }

    func hunks(context: Int = 3) -> [Hunk] {
        guard !lines.isEmpty else { return [] }
        let changed = lines.indices.filter { lines[$0].operation != .equal }
        guard !changed.isEmpty else { return [] }
        let radius = max(0, context)
        var regions: [Range<Int>] = []
        for index in changed {
            let before = min(index, radius)
            let after = min(lines.count - 1 - index, radius)
            let region = (index - before)..<(index + after + 1)
            if let last = regions.last, region.lowerBound <= last.upperBound {
                regions[regions.count - 1] = last.lowerBound..<max(last.upperBound, region.upperBound)
            } else {
                regions.append(region)
            }
        }
        var oldPrefix = [Int](repeating: 0, count: lines.count + 1)
        var newPrefix = [Int](repeating: 0, count: lines.count + 1)
        for index in lines.indices {
            oldPrefix[index + 1] = oldPrefix[index] + (lines[index].operation == .insert ? 0 : 1)
            newPrefix[index + 1] = newPrefix[index] + (lines[index].operation == .delete ? 0 : 1)
        }
        return regions.map { region in
            let oldCount = oldPrefix[region.upperBound] - oldPrefix[region.lowerBound]
            let newCount = newPrefix[region.upperBound] - newPrefix[region.lowerBound]
            return Hunk(
                indices: region,
                oldStart: oldPrefix[region.lowerBound] + (oldCount > 0 ? 1 : 0),
                oldCount: oldCount,
                newStart: newPrefix[region.lowerBound] + (newCount > 0 ? 1 : 0),
                newCount: newCount
            )
        }
    }
}
