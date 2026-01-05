import Foundation

struct Area {
    let index: Int
    let rows: Int
    let cols: Int
    let mines: Int
    let specialMineChance: Double
}

final class WorldGenerator {
    private let baseRows = 8
    private let baseCols = 8
    private let baseMineDensity = 0.14

    func generateArea(index: Int) -> Area {
        let growth = max(0, index)
        let rows = min(20, baseRows + growth * 2)
        let cols = min(20, baseCols + growth * 2)
        let density = min(0.22, baseMineDensity + Double(growth) * 0.01)
        let mines = max(8, Int(Double(rows * cols) * density))
        let specialChance = min(0.35, 0.05 + Double(growth) * 0.03)
        return Area(index: index, rows: rows, cols: cols, mines: mines, specialMineChance: specialChance)
    }
}
