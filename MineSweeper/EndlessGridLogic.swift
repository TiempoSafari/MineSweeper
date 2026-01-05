import Foundation

struct GridTile {
    let row: Int
    let col: Int
    var hasMine: Bool
    var state: TileState
    var adjacentMines: Int
    var hasBeenVisited: Bool
}

enum TileState {
    case unrevealed
    case revealed
    case flagged
}

final class GridLogic {
    let rows: Int
    let cols: Int
    let mineCount: Int
    private(set) var tiles: [[GridTile]]

    init(rows: Int, cols: Int, mineCount: Int) {
        self.rows = rows
        self.cols = cols
        self.mineCount = min(mineCount, rows * cols - 1)
        self.tiles = []
        generateGrid()
    }

    func tile(atRow row: Int, col: Int) -> GridTile? {
        guard rowsRange.contains(row), colsRange.contains(col) else { return nil }
        return tiles[row][col]
    }

    func setVisited(row: Int, col: Int) {
        guard rowsRange.contains(row), colsRange.contains(col) else { return }
        tiles[row][col].hasBeenVisited = true
    }

    func reveal(row: Int, col: Int) -> [GridTile] {
        guard rowsRange.contains(row), colsRange.contains(col) else { return [] }
        if tiles[row][col].state != .unrevealed { return [] }

        var revealed: [GridTile] = []
        var queue: [(Int, Int)] = [(row, col)]

        while let (currentRow, currentCol) = queue.first {
            queue.removeFirst()
            if tiles[currentRow][currentCol].state != .unrevealed { continue }

            tiles[currentRow][currentCol].state = .revealed
            revealed.append(tiles[currentRow][currentCol])

            if tiles[currentRow][currentCol].adjacentMines == 0 && !tiles[currentRow][currentCol].hasMine {
                for (adjRow, adjCol) in neighbors(ofRow: currentRow, col: currentCol) {
                    if tiles[adjRow][adjCol].state == .unrevealed {
                        queue.append((adjRow, adjCol))
                    }
                }
            }
        }

        return revealed
    }

    func revealNeighbors(fromRow row: Int, col: Int, radius: Int) -> [GridTile] {
        guard radius > 0 else { return [] }
        var revealed: [GridTile] = []
        for r in max(0, row - radius)...min(rows - 1, row + radius) {
            for c in max(0, col - radius)...min(cols - 1, col + radius) {
                if tiles[r][c].state == .unrevealed {
                    tiles[r][c].state = .revealed
                    revealed.append(tiles[r][c])
                }
            }
        }
        return revealed
    }

    func toggleFlag(row: Int, col: Int) {
        guard rowsRange.contains(row), colsRange.contains(col) else { return }
        switch tiles[row][col].state {
        case .unrevealed:
            tiles[row][col].state = .flagged
        case .flagged:
            tiles[row][col].state = .unrevealed
        case .revealed:
            break
        }
    }

    func remainingSafeTiles() -> Int {
        let totalSafe = rows * cols - mineCount
        let revealedSafe = tiles.flatMap { $0 }.filter { $0.state == .revealed && !$0.hasMine }.count
        return max(0, totalSafe - revealedSafe)
    }

    private func generateGrid() {
        tiles = (0..<rows).map { row in
            (0..<cols).map { col in
                GridTile(row: row, col: col, hasMine: false, state: .unrevealed, adjacentMines: 0, hasBeenVisited: false)
            }
        }

        var minePositions = Set<String>()
        while minePositions.count < mineCount {
            let row = Int.random(in: 0..<rows)
            let col = Int.random(in: 0..<cols)
            minePositions.insert("\(row)-\(col)")
        }

        for key in minePositions {
            let parts = key.split(separator: "-")
            guard parts.count == 2, let row = Int(parts[0]), let col = Int(parts[1]) else { continue }
            tiles[row][col].hasMine = true
        }

        for row in 0..<rows {
            for col in 0..<cols {
                let adjacent = neighbors(ofRow: row, col: col)
                let count = adjacent.filter { tiles[$0.0][$0.1].hasMine }.count
                tiles[row][col].adjacentMines = count
            }
        }
    }

    private func neighbors(ofRow row: Int, col: Int) -> [(Int, Int)] {
        var results: [(Int, Int)] = []
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let r = row + dr
                let c = col + dc
                if rowsRange.contains(r), colsRange.contains(c) {
                    results.append((r, c))
                }
            }
        }
        return results
    }

    private var rowsRange: Range<Int> { 0..<rows }
    private var colsRange: Range<Int> { 0..<cols }
}
