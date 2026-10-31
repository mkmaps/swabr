import CoreGraphics

/// Squarified treemap layout (Bruls, Huizing, van Wijk).
public enum Treemap {
    public struct Tile: Sendable {
        public let index: Int
        public let rect: CGRect
    }

    /// Lays out `values` (any order) inside `rect`. Zero values get no tile.
    public static func layout(_ values: [Double], in rect: CGRect) -> [Tile] {
        let items = values.enumerated().filter { $0.element > 0 }.sorted { $0.element > $1.element }
        let total = items.reduce(0) { $0 + $1.element }
        guard total > 0, rect.width > 0, rect.height > 0 else { return [] }
        let scale = Double(rect.width * rect.height) / total
        var queue = items.map { (index: $0.offset, area: $0.element * scale) }

        var tiles: [Tile] = []
        var free = rect
        var row: [(index: Int, area: Double)] = []

        func worst(_ row: [(index: Int, area: Double)], side: Double) -> Double {
            let sum = row.reduce(0) { $0 + $1.area }
            guard let maxA = row.map(\.area).max(), let minA = row.map(\.area).min(), sum > 0 else { return .infinity }
            let s2 = side * side, sum2 = sum * sum
            return max(s2 * maxA / sum2, sum2 / (s2 * minA))
        }

        func place(_ row: [(index: Int, area: Double)]) {
            let sum = row.reduce(0) { $0 + $1.area }
            let horizontal = free.width >= free.height
            if horizontal {
                let w = CGFloat(sum) / free.height
                var y = free.minY
                for item in row {
                    let h = CGFloat(item.area) / w
                    tiles.append(Tile(index: item.index, rect: CGRect(x: free.minX, y: y, width: w, height: h)))
                    y += h
                }
                free = CGRect(x: free.minX + w, y: free.minY, width: max(0, free.width - w), height: free.height)
            } else {
                let h = CGFloat(sum) / free.width
                var x = free.minX
                for item in row {
                    let w = CGFloat(item.area) / h
                    tiles.append(Tile(index: item.index, rect: CGRect(x: x, y: free.minY, width: w, height: h)))
                    x += w
                }
                free = CGRect(x: free.minX, y: free.minY + h, width: free.width, height: max(0, free.height - h))
            }
        }

        while !queue.isEmpty {
            let side = Double(min(free.width, free.height))
            let next = queue[0]
            if row.isEmpty || worst(row + [next], side: side) <= worst(row, side: side) {
                row.append(next)
                queue.removeFirst()
            } else {
                place(row)
                row = []
            }
        }
        if !row.isEmpty { place(row) }
        return tiles
    }
}
