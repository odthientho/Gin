import Foundation

/// Picks a grid arrangement that fills the screen.
///
/// Gin never scrolls, so every grid has to fit exactly. A half-empty last row
/// wastes the tile size that makes targets easy for small hands to hit, so the
/// rule is: cap the rows, prefer the arrangement with the fewest empty cells,
/// and break ties toward tiles that stay roughly square on a landscape iPad.
enum GridFit {
    static func columnCount(
        for count: Int,
        maxRows: Int = 3,
        landscapeAspect: Double = 1.73
    ) -> Int {
        guard count > 1 else { return 1 }

        let idealForAspect = (Double(count) * landscapeAspect).squareRoot()

        let candidates = (2 ... 6).filter { columns in
            rows(count: count, columns: columns) <= maxRows
        }
        guard !candidates.isEmpty else { return 6 }

        func emptyCells(_ columns: Int) -> Int {
            columns * rows(count: count, columns: columns) - count
        }

        return candidates.min { lhs, rhs in
            let (emptyL, emptyR) = (emptyCells(lhs), emptyCells(rhs))
            if emptyL != emptyR { return emptyL < emptyR }
            return abs(Double(lhs) - idealForAspect) < abs(Double(rhs) - idealForAspect)
        } ?? 3
    }

    static func rows(count: Int, columns: Int) -> Int {
        guard columns > 0 else { return count }
        return Int((Double(count) / Double(columns)).rounded(.up))
    }

    /// Splits items into rows of `columns`.
    static func chunk<T>(_ items: [T], into columns: Int) -> [[T]] {
        guard columns > 0 else { return [items] }
        return stride(from: 0, to: items.count, by: columns).map { start in
            Array(items[start ..< min(start + columns, items.count)])
        }
    }
}
