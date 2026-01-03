//
//  GameScene.swift
//  MineSweeper
//
//  Created by 山枫 on 2026/1/3.
//

import SpriteKit
import GameplayKit

final class GameScene: SKScene {
    enum Difficulty: CaseIterable {
        case easy
        case medium
        case hard

        var title: String {
            switch self {
            case .easy: return "简单"
            case .medium: return "中等"
            case .hard: return "困难"
            }
        }

        var configuration: (rows: Int, cols: Int, mines: Int) {
            switch self {
            case .easy:
                return (8, 8, 10)
            case .medium:
                return (12, 10, 20)
            case .hard:
                return (16, 12, 35)
            }
        }
    }

    struct TouchInfo {
        let startTime: TimeInterval
        let startPoint: CGPoint
    }

    final class Cell {
        let row: Int
        let col: Int
        var hasMine = false
        var isRevealed = false
        var isFlagged = false
        var adjacentMines = 0
        let node: SKShapeNode
        let label: SKLabelNode

        init(row: Int, col: Int, node: SKShapeNode, label: SKLabelNode) {
            self.row = row
            self.col = col
            self.node = node
            self.label = label
        }
    }

    var entities = [GKEntity]()
    var graphs = [String: GKGraph]()

    private var boardNode = SKNode()
    private var cells: [[Cell]] = []
    private var touchInfo: [ObjectIdentifier: TouchInfo] = [:]
    private var statusLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private var mineLabel = SKLabelNode(fontNamed: "HelveticaNeue")
    private var boardOrigin = CGPoint.zero
    private var tileSize: CGFloat = 0
    private var rows = 8
    private var cols = 8
    private var mineCount = 10
    private var isWaitingForStart = true
    private var isFirstMove = true
    private var isGameOver = false
    private var revealedCount = 0

    override func didMove(to view: SKView) {
        backgroundColor = SKColor.systemBackground
        configureLabels()
        showStartState()
    }

    private func configureLabels() {
        statusLabel.fontSize = 28
        statusLabel.fontColor = SKColor.label
        statusLabel.horizontalAlignmentMode = .center
        statusLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 60)
        statusLabel.zPosition = 10
        addChild(statusLabel)

        mineLabel.fontSize = 18
        mineLabel.fontColor = SKColor.secondaryLabel
        mineLabel.horizontalAlignmentMode = .center
        mineLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 90)
        mineLabel.zPosition = 10
        addChild(mineLabel)
    }

    private func startNewGame() {
        boardNode.removeFromParent()
        boardNode = SKNode()
        addChild(boardNode)

        isFirstMove = true
        isGameOver = false
        isWaitingForStart = false
        revealedCount = 0

        statusLabel.text = "扫雷"
        setupBoard()
        updateMineLabel()
    }

    func startGame(difficulty: Difficulty) {
        let configuration = difficulty.configuration
        rows = configuration.rows
        cols = configuration.cols
        mineCount = configuration.mines
        startNewGame()
    }

    private func showStartState() {
        boardNode.removeFromParent()
        boardNode = SKNode()
        addChild(boardNode)
        isWaitingForStart = true
        isGameOver = false
        isFirstMove = true
        revealedCount = 0
        statusLabel.text = "选择难度开始"
        mineLabel.text = ""
    }

    private func setupBoard() {
        let availableHeight = size.height - 140
        let boardSize = min(size.width - 40, availableHeight)
        tileSize = floor(boardSize / CGFloat(max(rows, cols)))
        let gridWidth = tileSize * CGFloat(cols)
        let gridHeight = tileSize * CGFloat(rows)
        boardOrigin = CGPoint(
            x: frame.midX - gridWidth / 2,
            y: frame.midY - gridHeight / 2 - 20
        )

        cells = []
        for row in 0..<rows {
            var rowCells: [Cell] = []
            for col in 0..<cols {
                let node = SKShapeNode(rectOf: CGSize(width: tileSize - 2, height: tileSize - 2), cornerRadius: 4)
                node.fillColor = SKColor.systemGray5
                node.strokeColor = SKColor.systemGray2
                node.lineWidth = 1
                node.position = positionFor(row: row, col: col)
                node.zPosition = 1

                let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
                label.fontSize = tileSize * 0.5
                label.fontColor = SKColor.label
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                label.text = ""
                label.zPosition = 2
                node.addChild(label)

                boardNode.addChild(node)
                let cell = Cell(row: row, col: col, node: node, label: label)
                rowCells.append(cell)
            }
            cells.append(rowCells)
        }
    }

    private func positionFor(row: Int, col: Int) -> CGPoint {
        CGPoint(
            x: boardOrigin.x + CGFloat(col) * tileSize + tileSize / 2,
            y: boardOrigin.y + CGFloat(rows - 1 - row) * tileSize + tileSize / 2
        )
    }

    private func updateMineLabel() {
        let flagged = cells.flatMap { $0 }.filter { $0.isFlagged }.count
        mineLabel.text = "地雷: \(mineCount)  标记: \(flagged)"
    }

    private func placeMines(excluding cell: Cell) {
        var available = cells.flatMap { $0 }.filter { $0.row != cell.row || $0.col != cell.col }
        let randomSource = GKARC4RandomSource()
        randomSource.dropValues(32)
        let shuffled = randomSource.arrayByShufflingObjects(in: available) as? [Cell] ?? available
        for mineCell in shuffled.prefix(mineCount) {
            mineCell.hasMine = true
        }
        for row in 0..<rows {
            for col in 0..<cols {
                cells[row][col].adjacentMines = countAdjacentMines(row: row, col: col)
            }
        }
    }

    private func countAdjacentMines(row: Int, col: Int) -> Int {
        var count = 0
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 {
                    continue
                }
                let r = row + dr
                let c = col + dc
                if r >= 0 && r < rows && c >= 0 && c < cols {
                    if cells[r][c].hasMine {
                        count += 1
                    }
                }
            }
        }
        return count
    }

    private func reveal(cell: Cell) {
        guard !cell.isRevealed, !cell.isFlagged else { return }
        if isFirstMove {
            placeMines(excluding: cell)
            isFirstMove = false
        }

        cell.isRevealed = true
        cell.node.fillColor = SKColor.systemGray4
        revealedCount += 1

        if cell.hasMine {
            cell.label.text = "💣"
            endGame(didWin: false)
            return
        }

        if cell.adjacentMines > 0 {
            cell.label.text = "\(cell.adjacentMines)"
            cell.label.fontColor = colorForMineCount(cell.adjacentMines)
        } else {
            cell.label.text = ""
            revealNeighbors(from: cell)
        }

        if revealedCount == rows * cols - mineCount {
            endGame(didWin: true)
        }
    }

    private func revealNeighbors(from cell: Cell) {
        var queue = [cell]
        var index = 0
        while index < queue.count {
            let current = queue[index]
            index += 1
            for dr in -1...1 {
                for dc in -1...1 {
                    let r = current.row + dr
                    let c = current.col + dc
                    if r >= 0 && r < rows && c >= 0 && c < cols {
                        let neighbor = cells[r][c]
                        if neighbor.isRevealed || neighbor.isFlagged {
                            continue
                        }
                        neighbor.isRevealed = true
                        neighbor.node.fillColor = SKColor.systemGray4
                        revealedCount += 1
                        if neighbor.hasMine {
                            neighbor.label.text = "💣"
                        } else if neighbor.adjacentMines > 0 {
                            neighbor.label.text = "\(neighbor.adjacentMines)"
                            neighbor.label.fontColor = colorForMineCount(neighbor.adjacentMines)
                        } else {
                            neighbor.label.text = ""
                            queue.append(neighbor)
                        }
                    }
                }
            }
        }
    }

    private func toggleFlag(for cell: Cell) {
        guard !cell.isRevealed else { return }
        cell.isFlagged.toggle()
        cell.label.text = cell.isFlagged ? "🚩" : ""
        cell.label.fontColor = SKColor.systemRed
        updateMineLabel()
    }

    private func endGame(didWin: Bool) {
        isGameOver = true
        statusLabel.text = didWin ? "你赢了！" : "踩到地雷了"
        mineLabel.text = "点击任意位置重新开始"
        revealAllMines()
    }

    private func revealAllMines() {
        for row in cells {
            for cell in row where cell.hasMine {
                cell.label.text = "💣"
                cell.node.fillColor = SKColor.systemRed.withAlphaComponent(0.2)
            }
        }
    }

    private func colorForMineCount(_ count: Int) -> SKColor {
        switch count {
        case 1: return SKColor.systemBlue
        case 2: return SKColor.systemGreen
        case 3: return SKColor.systemOrange
        case 4: return SKColor.systemPurple
        default: return SKColor.systemRed
        }
    }

    private func cell(at point: CGPoint) -> Cell? {
        let col = Int((point.x - boardOrigin.x) / tileSize)
        let rowFromBottom = Int((point.y - boardOrigin.y) / tileSize)
        let row = rows - 1 - rowFromBottom
        guard row >= 0, row < rows, col >= 0, col < cols else { return nil }
        return cells[row][col]
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            touchInfo[identifier] = TouchInfo(startTime: touch.timestamp, startPoint: touch.location(in: self))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            guard let info = touchInfo.removeValue(forKey: identifier) else { continue }
            let endPoint = touch.location(in: self)
            let duration = touch.timestamp - info.startTime

            if isWaitingForStart {
                continue
            }

            if isGameOver {
                startNewGame()
                continue
            }

            guard let targetCell = cell(at: endPoint) else { continue }
            if duration > 0.35 {
                toggleFlag(for: targetCell)
            } else {
                reveal(cell: targetCell)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            touchInfo.removeValue(forKey: identifier)
        }
    }
}
