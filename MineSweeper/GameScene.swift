//
//  GameScene.swift
//  MineSweeper
//
//  Created by 山枫 on 2026/1/3.
//

import SpriteKit
import GameplayKit
import UIKit

protocol GameSceneDelegate: AnyObject {
    func gameSceneDidRequestStartMenu(_ scene: GameScene)
    func gameSceneDidStartGame(_ scene: GameScene)
    func gameScene(_ scene: GameScene, didEndWithWin didWin: Bool)
}

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

    weak var uiDelegate: GameSceneDelegate?

    private var boardNode = SKNode()
    private var cells: [[Cell]] = []

    private struct LongPressState {
        let startTime: TimeInterval
        let location: CGPoint
    }

    private var touchInfo: [ObjectIdentifier: LongPressState] = [:]
    private var touchRevealTimers: [ObjectIdentifier: Timer] = [:]
    private let longPressThreshold: TimeInterval = 0.4

    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    private var statusLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private var mineLabel = SKLabelNode(fontNamed: "HelveticaNeue")
    private var statusBackground = SKShapeNode()
    private var mineBackground = SKShapeNode()
    private var backgroundNode = SKSpriteNode()

    private var boardOrigin = CGPoint.zero
    private var tileSize: CGFloat = 0
    private var gridSize = CGSize.zero
    private let tileSizeFixed: CGFloat = 66

    private var rows = 8
    private var cols = 8
    private var mineCount = 10

    private var isWaitingForStart = true
    private var isFirstMove = true
    private var isGameOver = false
    private var revealedCount = 0

    // MARK: - Inertia Pan (轻微惯性) —— 更像 UIScrollView

    private var inertiaVelocity = CGPoint.zero      // points/sec (UIKit 坐标系速度)
    private var lastUpdateTime: TimeInterval = 0

    // 惯性强度：越小停得越快（UIScrollView decelerationRate 的思路）
    private let inertiaDecelerationRate: CGFloat = 0.86   // 0.82~0.90 都可以微调
    private let inertiaVelocityScale: CGFloat = 0.22      // 0.18~0.25：越大惯性越明显
    private let inertiaMaxSpeed: CGFloat = 1600
    private let inertiaEpsilon: CGFloat = 6               // 很小的速度才停（避免硬切顿挫）

    func stopInertiaPan() {
        inertiaVelocity = .zero
    }

    func startInertiaPan(initialVelocity: CGPoint) {
        guard !isWaitingForStart, !isGameOver else { return }

        // 重置，避免第一帧 dt 偶发偏大导致突变
        lastUpdateTime = 0

        var v = CGPoint(x: initialVelocity.x * inertiaVelocityScale,
                        y: initialVelocity.y * inertiaVelocityScale)

        let speed = hypot(v.x, v.y)
        if speed > inertiaMaxSpeed, speed > 0 {
            let k = inertiaMaxSpeed / speed
            v.x *= k
            v.y *= k
        }
        inertiaVelocity = v
    }


    // MARK: - Visual Palette (增强未翻开/已翻开对比)

    private let unrevealedFill = SKColor.systemTeal.withAlphaComponent(0.42)
    private let unrevealedStroke = SKColor.systemTeal.withAlphaComponent(0.95)

    private let revealedFill = SKColor.white.withAlphaComponent(0.70)
    private let revealedStroke = SKColor.systemGray.withAlphaComponent(0.35)

    private func applyUnrevealedStyle(to cell: Cell) {
        cell.node.fillColor = unrevealedFill
        cell.node.strokeColor = unrevealedStroke
        cell.node.lineWidth = 1
        cell.node.glowWidth = 1.5
    }

    private func applyRevealedStyle(to cell: Cell) {
        cell.node.fillColor = revealedFill
        cell.node.strokeColor = revealedStroke
        cell.node.lineWidth = 1
        cell.node.glowWidth = 0
    }

    // MARK: - Neighbor Preview Highlight (按住数字格，高亮周围)

    private let highlightOverlayName = "neighborPreviewOverlay"
    private var previewSourceByTouch: [ObjectIdentifier: Cell] = [:]

    private func neighbors(of cell: Cell) -> [Cell] {
        var result: [Cell] = []
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let r = cell.row + dr
                let c = cell.col + dc
                if r >= 0 && r < rows && c >= 0 && c < cols {
                    result.append(cells[r][c])
                }
            }
        }
        return result
    }

    private func showNeighborPreview(for source: Cell, touchId: ObjectIdentifier) {
        clearNeighborPreview(touchId: touchId)
        previewSourceByTouch[touchId] = source

        let overlayFill = SKColor.white.withAlphaComponent(0.12)
        let overlayStroke = SKColor.white.withAlphaComponent(0.55)

        for cell in neighbors(of: source) {
            cell.node.childNode(withName: highlightOverlayName)?.removeFromParent()

            let overlay = SKShapeNode(
                rectOf: CGSize(width: tileSize - 6, height: tileSize - 6),
                cornerRadius: 8
            )
            overlay.name = highlightOverlayName
            overlay.fillColor = cell.isFlagged ? .clear : overlayFill
            overlay.strokeColor = overlayStroke
            overlay.lineWidth = 2
            overlay.glowWidth = 6
            overlay.zPosition = 3
            overlay.alpha = 0.85

            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 1.0, duration: 0.25),
                SKAction.fadeAlpha(to: 0.75, duration: 0.25)
            ])
            overlay.run(SKAction.repeatForever(pulse))

            cell.node.addChild(overlay)
        }
    }

    private func clearAllNeighborPreviewOverlays() {
        for row in cells {
            for cell in row {
                cell.node.childNode(withName: highlightOverlayName)?.removeFromParent()
            }
        }
        previewSourceByTouch.removeAll()
    }

    private func clearNeighborPreview(touchId: ObjectIdentifier) {
        previewSourceByTouch.removeValue(forKey: touchId)
        clearAllNeighborPreviewOverlays()
    }

    // MARK: - Chord (数字格自动翻开邻居)

    private func flaggedNeighborCount(of cell: Cell) -> Int {
        neighbors(of: cell).filter { $0.isFlagged }.count
    }

    private func chordReveal(from cell: Cell) {
        guard !isWaitingForStart, !isGameOver else { return }
        guard cell.isRevealed, !cell.hasMine, cell.adjacentMines > 0 else { return }

        let flagged = flaggedNeighborCount(of: cell)
        guard flagged == cell.adjacentMines else { return }

        // 触发 chord 时震动反馈
        feedbackGenerator.impactOccurred()
        feedbackGenerator.prepare()

        clearAllNeighborPreviewOverlays()

        for n in neighbors(of: cell) {
            if isGameOver { break }
            if n.isFlagged || n.isRevealed { continue }
            reveal(cell: n)
        }
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor.systemBackground
        configureBackground()
        configureLabels()
        childNode(withName: "//helloLabel")?.removeFromParent()
        feedbackGenerator.prepare()
        showStartState()
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }

        var dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // dt 防抖：避免某一帧卡顿导致移动/衰减突变
        dt = min(dt, 1.0 / 30.0)

        guard !isWaitingForStart, !isGameOver else {
            inertiaVelocity = .zero
            return
        }

        let speed = hypot(inertiaVelocity.x, inertiaVelocity.y)
        if speed < inertiaEpsilon {
            inertiaVelocity = .zero
            return
        }

        // 先移动
        let translation = CGPoint(x: inertiaVelocity.x * CGFloat(dt),
                                  y: inertiaVelocity.y * CGFloat(dt))
        panBoard(by: translation)

        // 再衰减（UIScrollView 风格：按帧率幂衰减，曲线更“物理”）
        let frames = CGFloat(dt) * 60.0
        let decay = pow(inertiaDecelerationRate, frames)
        inertiaVelocity.x *= decay
        inertiaVelocity.y *= decay
    }

    // MARK: - Labels UI

    private func configureLabels() {
        statusLabel.fontSize = 26
        statusLabel.fontColor = SKColor.label
        statusLabel.horizontalAlignmentMode = .center
        statusLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 60)
        statusLabel.zPosition = 10
        addChild(statusLabel)

        mineLabel.fontSize = 17
        mineLabel.fontColor = SKColor.secondaryLabel
        mineLabel.horizontalAlignmentMode = .center
        mineLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 90)
        mineLabel.zPosition = 10
        addChild(mineLabel)

        statusBackground = labelBackdrop(for: statusLabel, horizontalPadding: 22, verticalPadding: 12)
        mineBackground = labelBackdrop(for: mineLabel, horizontalPadding: 20, verticalPadding: 10)
        addChild(statusBackground)
        addChild(mineBackground)
        updateLabelBackdrops()
    }

    private func labelBackdrop(for label: SKLabelNode, horizontalPadding: CGFloat, verticalPadding: CGFloat) -> SKShapeNode {
        let size = CGSize(width: label.frame.width + horizontalPadding, height: label.frame.height + verticalPadding)
        let node = SKShapeNode(rectOf: size, cornerRadius: size.height / 2)
        node.fillColor = SKColor.white.withAlphaComponent(0.18)
        node.strokeColor = SKColor.white.withAlphaComponent(0.35)
        node.lineWidth = 1
        node.glowWidth = 2
        node.zPosition = label.zPosition - 1
        node.position = label.position
        return node
    }

    private func updateLabelBackdrops() {
        statusBackground.removeFromParent()
        mineBackground.removeFromParent()
        statusBackground = labelBackdrop(for: statusLabel, horizontalPadding: 22, verticalPadding: 12)
        mineBackground = labelBackdrop(for: mineLabel, horizontalPadding: 20, verticalPadding: 10)
        addChild(statusBackground)
        addChild(mineBackground)
    }

    // MARK: - Game Flow

    private func startNewGame() {
        stopInertiaPan()

        boardNode.removeFromParent()
        boardNode = SKNode()
        addChild(boardNode)

        clearAllNeighborPreviewOverlays()

        isFirstMove = true
        isGameOver = false
        isWaitingForStart = false
        revealedCount = 0

        statusLabel.text = "扫雷"
        updateLabelBackdrops()
        setupBoard()
        updateMineLabel()
        uiDelegate?.gameSceneDidStartGame(self)
    }

    func startGame(difficulty: Difficulty) {
        let configuration = difficulty.configuration
        rows = configuration.rows
        cols = configuration.cols
        mineCount = configuration.mines
        startNewGame()
    }

    func startGame(rows: Int, cols: Int, mines: Int) {
        self.rows = max(4, rows)
        self.cols = max(4, cols)
        mineCount = max(1, mines)
        startNewGame()
    }

    func showStartState() {
        stopInertiaPan()

        boardNode.removeFromParent()
        boardNode = SKNode()
        addChild(boardNode)

        clearAllNeighborPreviewOverlays()

        isWaitingForStart = true
        isGameOver = false
        isFirstMove = true
        revealedCount = 0
        statusLabel.text = "选择难度开始"
        mineLabel.text = ""
        updateLabelBackdrops()
    }

    // MARK: - Board Setup

    private func setupBoard() {
        tileSize = tileSizeFixed
        let gridWidth = tileSize * CGFloat(cols)
        let gridHeight = tileSize * CGFloat(rows)
        gridSize = CGSize(width: gridWidth, height: gridHeight)
        boardOrigin = clampedBoardOrigin(proposed: CGPoint(
            x: frame.midX - gridWidth / 2,
            y: frame.midY - gridHeight / 2 - 20
        ))
        boardNode.position = boardOrigin

        cells = []
        for row in 0..<rows {
            var rowCells: [Cell] = []
            for col in 0..<cols {
                let node = SKShapeNode(
                    rectOf: CGSize(width: tileSize - 2, height: tileSize - 2),
                    cornerRadius: 6
                )
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
                applyUnrevealedStyle(to: cell)
                rowCells.append(cell)
            }
            cells.append(rowCells)
        }
    }

    private func positionFor(row: Int, col: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(col) * tileSize + tileSize / 2,
            y: CGFloat(rows - 1 - row) * tileSize + tileSize / 2
        )
    }

    // MARK: - Mines

    private func updateMineLabel() {
        let flagged = cells.flatMap { $0 }.filter { $0.isFlagged }.count
        mineLabel.text = "地雷: \(mineCount)  标记: \(flagged)"
        updateLabelBackdrops()
    }

    private func placeMines(excluding cell: Cell) {
        let available = cells.flatMap { $0 }.filter { $0.row != cell.row || $0.col != cell.col }
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
                if dr == 0 && dc == 0 { continue }
                let r = row + dr
                let c = col + dc
                if r >= 0 && r < rows && c >= 0 && c < cols {
                    if cells[r][c].hasMine { count += 1 }
                }
            }
        }
        return count
    }

    // MARK: - Reveal / Flag

    private func reveal(cell: Cell) {
        guard !cell.isRevealed, !cell.isFlagged else { return }

        clearAllNeighborPreviewOverlays()

        if isFirstMove {
            placeMines(excluding: cell)
            isFirstMove = false
        }

        cell.isRevealed = true
        applyRevealedStyle(to: cell)

        revealedCount += 1
        feedbackGenerator.impactOccurred()
        feedbackGenerator.prepare()

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
                        if neighbor.isRevealed || neighbor.isFlagged { continue }

                        neighbor.isRevealed = true
                        applyRevealedStyle(to: neighbor)

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

    // MARK: - End Game

    private func endGame(didWin: Bool) {
        stopInertiaPan()

        isGameOver = true
        clearAllNeighborPreviewOverlays()

        statusLabel.text = didWin ? "你赢了！" : "踩到地雷了"
        mineLabel.text = "点击确定返回主界面"
        revealAllMines()
        updateLabelBackdrops()
        uiDelegate?.gameScene(self, didEndWithWin: didWin)
    }

    private func revealAllMines() {
        for row in cells {
            for cell in row where cell.hasMine {
                cell.label.text = "💣"
                cell.node.fillColor = SKColor.systemRed.withAlphaComponent(0.3)
                cell.node.strokeColor = SKColor.systemRed.withAlphaComponent(0.6)
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

    // MARK: - Touch Handling

    private func cell(at point: CGPoint) -> Cell? {
        let localPoint = convert(point, to: boardNode)
        let col = Int(localPoint.x / tileSize)
        let rowFromBottom = Int(localPoint.y / tileSize)
        let row = rows - 1 - rowFromBottom
        guard row >= 0, row < rows, col >= 0, col < cols else { return nil }
        return cells[row][col]
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 手指开始操作时，停掉惯性（避免“边滑边点”）
        stopInertiaPan()

        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            let location = touch.location(in: self)

            if !isWaitingForStart, !isGameOver,
               let c = cell(at: location),
               c.isRevealed, !c.hasMine, c.adjacentMines > 0 {

                touchInfo[identifier] = LongPressState(startTime: touch.timestamp, location: location)
                showNeighborPreview(for: c, touchId: identifier)
                continue
            }

            touchInfo[identifier] = LongPressState(startTime: touch.timestamp, location: location)

            let timer = Timer.scheduledTimer(withTimeInterval: longPressThreshold, repeats: false) { [weak self] _ in
                guard let self = self,
                      let state = self.touchInfo[identifier],
                      self.isWaitingForStart == false,
                      self.isGameOver == false else {
                    return
                }
                guard let targetCell = self.cell(at: state.location) else { return }
                self.reveal(cell: targetCell)
            }
            touchRevealTimers[identifier] = timer
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let endPoint = touch.location(in: self)
            let identifier = ObjectIdentifier(touch)

            clearNeighborPreview(touchId: identifier)

            touchRevealTimers[identifier]?.invalidate()
            touchRevealTimers.removeValue(forKey: identifier)

            let startState = touchInfo.removeValue(forKey: identifier)
            let duration = touch.timestamp - (startState?.startTime ?? touch.timestamp)

            if isWaitingForStart || isGameOver { continue }
            guard let targetCell = cell(at: endPoint) else { continue }

            if duration < longPressThreshold {
                if targetCell.isRevealed, !targetCell.hasMine, targetCell.adjacentMines > 0 {
                    chordReveal(from: targetCell)
                } else {
                    toggleFlag(for: targetCell)
                }
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            clearNeighborPreview(touchId: identifier)

            touchInfo.removeValue(forKey: identifier)
            touchRevealTimers[identifier]?.invalidate()
            touchRevealTimers.removeValue(forKey: identifier)
        }
    }

    // MARK: - Background / Board Pan

    private func configureBackground() {
        backgroundNode.removeFromParent()
        let texture = gradientTexture(
            start: UIColor(red: 0.76, green: 0.86, blue: 1.0, alpha: 1.0),
            end: UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1.0)
        )
        backgroundNode = SKSpriteNode(texture: texture, size: size)
        backgroundNode.position = CGPoint(x: frame.midX, y: frame.midY)
        backgroundNode.zPosition = -10
        addChild(backgroundNode)
    }

    private func gradientTexture(start: UIColor, end: UIColor) -> SKTexture {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [start.cgColor, end.cgColor]
        gradientLayer.frame = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            gradientLayer.render(in: context.cgContext)
        }
        return SKTexture(image: image)
    }

    private func clampedBoardOrigin(proposed: CGPoint) -> CGPoint {
        let margin: CGFloat = 24
        let viewWidth = size.width
        let viewHeight = size.height

        if gridSize.width <= viewWidth - margin * 2,
           gridSize.height <= viewHeight - margin * 2 {
            return CGPoint(
                x: frame.midX - gridSize.width / 2,
                y: frame.midY - gridSize.height / 2 - 20
            )
        }

        let minX = frame.minX + margin - gridSize.width
        let maxX = frame.maxX - margin
        let minY = frame.minY + margin - gridSize.height
        let maxY = frame.maxY - margin

        return CGPoint(
            x: min(max(proposed.x, minX), maxX),
            y: min(max(proposed.y, minY), maxY)
        )
    }

    func panBoard(by translation: CGPoint) {
        guard !isWaitingForStart else { return }
        let proposed = CGPoint(x: boardNode.position.x + translation.x,
                               y: boardNode.position.y - translation.y) // 注意这里 y 方向与 UIKit 相反
        let clamped = clampedBoardOrigin(proposed: proposed)
        boardNode.position = clamped
    }
}
