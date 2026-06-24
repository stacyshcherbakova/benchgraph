import Foundation

/// Translates a p-value into the star code used on published figures.
public enum Significance {

    /// The conventional GraphPad-style star code for a p-value:
    /// `****` < 0.0001, `***` < 0.001, `**` < 0.01, `*` < 0.05, else `ns`.
    /// A non-finite p (degenerate test) yields an empty string.
    public static func stars(_ p: Double) -> String {
        guard p.isFinite else { return "" }
        if p < 0.0001 { return "****" }
        if p < 0.001  { return "***" }
        if p < 0.01   { return "**" }
        if p < 0.05   { return "*" }
        return "ns"
    }
}

/// A significance annotation linking two bars on a column chart: a bracket
/// spanning bars `fromIndex`…`toIndex` with `label` (e.g. "*" or "ns") above it.
///
/// `level` is the vertical stacking row, filled in by ``BracketLayout`` so that
/// overlapping comparisons don't collide. Renderers consume this directly.
public struct BarBracket: Sendable, Equatable {
    public let fromIndex: Int
    public let toIndex: Int
    public let label: String
    public var level: Int

    public init(fromIndex: Int, toIndex: Int, label: String, level: Int = 0) {
        self.fromIndex = fromIndex
        self.toIndex = toIndex
        self.label = label
        self.level = level
    }

    /// Lower and upper bar indices, regardless of comparison direction.
    public var lo: Int { Swift.min(fromIndex, toIndex) }
    public var hi: Int { Swift.max(fromIndex, toIndex) }
}

/// Assigns non-overlapping stacking levels to significance brackets so that a
/// figure with several pairwise comparisons stays readable.
public enum BracketLayout {

    /// Return the brackets with `level` filled in (0 = closest to the bars).
    ///
    /// Narrower spans are placed first so that wide brackets float above the
    /// comparisons they enclose, matching how multi-comparison figures are
    /// usually drawn by hand.
    public static func assignLevels(_ brackets: [BarBracket]) -> [BarBracket] {
        let order = brackets.indices.sorted { i, j in
            let span = (brackets[i].hi - brackets[i].lo) - (brackets[j].hi - brackets[j].lo)
            return span != 0 ? span < 0 : brackets[i].lo < brackets[j].lo
        }
        var result = brackets
        var placed: [BarBracket] = []
        for idx in order {
            var level = 0
            while placed.contains(where: { $0.level == level && overlaps($0, result[idx]) }) {
                level += 1
            }
            result[idx].level = level
            placed.append(result[idx])
        }
        return result
    }

    /// Two brackets clash only when their bar spans genuinely overlap.
    /// Brackets that merely touch at a shared endpoint (e.g. A–B and B–C) may
    /// share a level, sitting side by side as on a hand-drawn comparison figure.
    private static func overlaps(_ a: BarBracket, _ b: BarBracket) -> Bool {
        a.lo < b.hi && b.lo < a.hi
    }
}
