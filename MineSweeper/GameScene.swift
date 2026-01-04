//
//  GameScene.swift
//  MineSweeper
//

import SpriteKit
import GameplayKit
import UIKit

protocol GameSceneDelegate: AnyObject {
    func gameSceneDidRequestStartMenu(_ scene: GameScene)
    func gameSceneDidStartGame(_ scene: GameScene)
    func gameScene(_ scene: GameScene, didEndWithWin didWin: Bool)

    // ✅ 新增：旗子数量更新（用于 UIKit HUD）
    func gameScene(_ scene: GameScene, didUpdateFlagCount flagged: Int, mineCount: Int)
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

    // 旧 HUD（SpriteKit）— 现在永久隐藏（UIKit HUD 接管）
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

    // MARK: - Inertia Pan (UIScrollView-like decay)

    private var inertiaVelocity = CGPoint.zero      // points/sec (UIKit coords)
    private var lastUpdateTime: TimeInterval = 0

    private let inertiaDecelerationRate: CGFloat = 0.84   // 更快停、更顺滑（0.82~0.90可调）
    private let inertiaVelocityScale: CGFloat = 0.22
    private let inertiaMaxSpeed: CGFloat = 1600
    private let inertiaEpsilon: CGFloat = 6

    func stopInertiaPan() { inertiaVelocity = .zero }

    func startInertiaPan(initialVelocity: CGPoint) {
        guard !isWaitingForStart, !isGameOver else { return }
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

    // MARK: - Glass Tile Style (SpriteKit native)

    private let glassOverlayName = "glassOverlay"
    private var glassTextureCache: [String: SKTexture] = [:]

    private func applyUnrevealedStyle(to cell: Cell) {
        // 先清掉旧 overlay
        cell.node.childNode(withName: glassOverlayName)?.removeFromParent()

        // 未翻开：更“毛玻璃”、更亮边缘
        cell.node.fillColor = .clear
        cell.node.strokeColor = .clear
        cell.node.glowWidth = 0
        cell.node.lineWidth = 0

        let tex = glassTileTexture(
            key: "unrevealed_\(Int(tileSize))",
            size: CGSize(width: tileSize - 2, height: tileSize - 2),
            cornerRadius: 10,
            baseAlpha: 0.38,          // 毛玻璃更“雾”
            borderAlpha: 0.35,
            highlightAlpha: 0.22,
            sheenAlpha: 0.18
        )

        let overlay = SKSpriteNode(texture: tex)
        overlay.name = glassOverlayName
        overlay.size = CGSize(width: tileSize - 2, height: tileSize - 2)
        overlay.zPosition = 1.5
        overlay.alpha = 1.0
        cell.node.addChild(overlay)
    }

    private func applyRevealedStyle(to cell: Cell) {
        cell.node.childNode(withName: glassOverlayName)?.removeFromParent()

        cell.node.fillColor = .clear
        cell.node.strokeColor = .clear
        cell.node.glowWidth = 0
        cell.node.lineWidth = 0

        let tex = glassTileTexture(
            key: "revealed_dark_v3_\(Int(tileSize))",   // ✅ 新 key，防缓存
            size: CGSize(width: tileSize - 2, height: tileSize - 2),
            cornerRadius: 10,
            baseAlpha: 0.10,        // ✅ 保持通透（不要加雾）
            borderAlpha: 0.22,
            highlightAlpha: 0.24,   // ✅ 玻璃高光仍然存在
            sheenAlpha: 0.18
        )

        let overlay = SKSpriteNode(texture: tex)
        overlay.name = glassOverlayName
        overlay.size = CGSize(width: tileSize - 2, height: tileSize - 2)
        overlay.zPosition = 1.5
        overlay.alpha = 1.0

        // ✅ 关键：用“深冷色”压暗，而不是灰/黑
        overlay.color = SKColor(
            red: 0.15,
            green: 0.25,
            blue: 0.30,
            alpha: 1.0
        )
        overlay.colorBlendFactor = 0.22   // ✅ 小比例，仍然透

        cell.node.addChild(overlay)
    }

    private func glassTileTexture(
        key: String,
        size: CGSize,
        cornerRadius: CGFloat,
        baseAlpha: CGFloat,
        borderAlpha: CGFloat,
        highlightAlpha: CGFloat,
        sheenAlpha: CGFloat
    ) -> SKTexture {
        if let cached = glassTextureCache[key] { return cached }

        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)

            // 背景：半透明“玻璃底”
            let baseColor = UIColor.white.withAlphaComponent(baseAlpha).cgColor
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            cg.addPath(path.cgPath)
            cg.setFillColor(baseColor)
            cg.fillPath()

            // 内阴影（让玻璃更有厚度）
            cg.saveGState()
            cg.addPath(path.cgPath)
            cg.clip()
            cg.setShadow(offset: CGSize(width: 0, height: 2), blur: 10, color: UIColor.black.withAlphaComponent(0.10).cgColor)
            cg.setFillColor(UIColor.clear.cgColor)
            cg.fill(rect.insetBy(dx: -20, dy: -20))
            cg.restoreGState()

            // 上侧高光（模拟曲率）
            cg.saveGState()
            cg.addPath(path.cgPath)
            cg.clip()
            let topGlowRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.45)
            let colors = [
                UIColor.white.withAlphaComponent(highlightAlpha).cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor
            ] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            cg.drawLinearGradient(grad,
                                  start: CGPoint(x: 0, y: 0),
                                  end: CGPoint(x: 0, y: topGlowRect.maxY),
                                  options: [])
            cg.restoreGState()

            // 斜向“高光带”（玻璃反光）
            cg.saveGState()
            cg.addPath(path.cgPath)
            cg.clip()

            let sheenPath = UIBezierPath()
            sheenPath.move(to: CGPoint(x: -size.width * 0.2, y: size.height * 0.15))
            sheenPath.addLine(to: CGPoint(x: size.width * 0.6, y: -size.height * 0.2))
            sheenPath.addLine(to: CGPoint(x: size.width * 1.2, y: size.height * 0.55))
            sheenPath.addLine(to: CGPoint(x: size.width * 0.4, y: size.height * 0.9))
            sheenPath.close()

            cg.addPath(sheenPath.cgPath)
            cg.setFillColor(UIColor.white.withAlphaComponent(sheenAlpha).cgColor)
            cg.fillPath()
            cg.restoreGState()

            // 边框（玻璃边缘）
            cg.addPath(path.cgPath)
            cg.setStrokeColor(UIColor.white.withAlphaComponent(borderAlpha).cgColor)
            cg.setLineWidth(1.0)
            cg.strokePath()

            // 细微外发光（更“玻璃”）
            cg.addPath(path.cgPath)
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.10).cgColor)
            cg.setLineWidth(2.0)
            cg.strokePath()
        }

        let texture = SKTexture(image: img)
        glassTextureCache[key] = texture
        return texture
    }

    // MARK: - Neighbor Preview Highlight

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

        // ✅ 永久隐藏旧 HUD（避免你截图红圈那块）
        setLegacyHUDVisible(false)

        showStartState()
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }

        var dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // dt 防抖
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

        let translation = CGPoint(x: inertiaVelocity.x * CGFloat(dt),
                                  y: inertiaVelocity.y * CGFloat(dt))
        panBoard(by: translation)

        let frames = CGFloat(dt) * 60.0
        let decay = pow(inertiaDecelerationRate, frames)
        inertiaVelocity.x *= decay
        inertiaVelocity.y *= decay
    }

    // MARK: - Legacy HUD (SpriteKit) — permanently hidden

    private func setLegacyHUDVisible(_ visible: Bool) {
        statusLabel.isHidden = !visible
        mineLabel.isHidden = !visible
        statusBackground.isHidden = !visible
        mineBackground.isHidden = !visible
    }

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

        // ✅ 仍保持隐藏（防止重建后又出现）
        setLegacyHUDVisible(false)
    }

    // MARK: - Game Flow

    private func startNewGame() {
        stopInertiaPan()
        clearAllNeighborPreviewOverlays()

        // ✅ 旧 HUD 永久隐藏
        setLegacyHUDVisible(false)

        boardNode.removeFromParent()
        boardNode = SKNode()
        addChild(boardNode)

        isFirstMove = true
        isGameOver = false
        isWaitingForStart = false
        revealedCount = 0

        setupBoard()
        updateMineLabel() // 这会触发 flag count 回调给 VC

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
        clearAllNeighborPreviewOverlays()

        // ✅ 旧 HUD 永久隐藏
        setLegacyHUDVisible(false)

        boardNode.removeFromParent()
        boardNode = SKNode()
        addChild(boardNode)

        isWaitingForStart = true
        isGameOver = false
        isFirstMove = true
        revealedCount = 0
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

    // MARK: - Mines (first move must chain open)

    private func updateMineLabel() {
        let flagged = cells.flatMap { $0 }.filter { $0.isFlagged }.count

        // 旧 HUD 虽然隐藏，但仍保留逻辑（无害）
        mineLabel.text = "地雷: \(mineCount)  标记: \(flagged)"
        updateLabelBackdrops()

        // ✅ 推送给 UIKit HUD
        uiDelegate?.gameScene(self, didUpdateFlagCount: flagged, mineCount: mineCount)
    }

    private func placeMines(excluding firstCell: Cell) {
        // ✅ 首翻必须连锁：排除首格 + 周围8格，保证首格 adjacentMines == 0
        func key(_ r: Int, _ c: Int) -> Int { r * cols + c }
        var excluded = Set<Int>()
        excluded.insert(key(firstCell.row, firstCell.col))
        for n in neighbors(of: firstCell) {
            excluded.insert(key(n.row, n.col))
        }

        var available = cells.flatMap { $0 }.filter { !excluded.contains(key($0.row, $0.col)) }

        // 兜底：如果雷太多导致不足，就至少保证首格不为雷
        if available.count < mineCount {
            excluded = [key(firstCell.row, firstCell.col)]
            available = cells.flatMap { $0 }.filter { !excluded.contains(key($0.row, $0.col)) }
        }

        // 清雷
        for r in 0..<rows {
            for c in 0..<cols {
                cells[r][c].hasMine = false
            }
        }

        let randomSource = GKARC4RandomSource()
        randomSource.dropValues(32)
        let shuffled = randomSource.arrayByShufflingObjects(in: available) as? [Cell] ?? available

        for mineCell in shuffled.prefix(mineCount) {
            mineCell.hasMine = true
        }

        for r in 0..<rows {
            for c in 0..<cols {
                cells[r][c].adjacentMines = countAdjacentMines(row: r, col: c)
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

    // 翻开格子
    private func reveal(cell: Cell) {
        guard !cell.isRevealed, !cell.isFlagged else { return }

        if isFirstMove {
            placeMines(excluding: cell)
            isFirstMove = false
        }

        cell.isRevealed = true
        revealedCount += 1

        feedbackGenerator.impactOccurred()
        feedbackGenerator.prepare()

        // 翻开后添加玻璃质感效果
        applyRevealedStyle(to: cell)

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
        revealAllMines()

        // 旧 HUD 永久隐藏
        setLegacyHUDVisible(false)

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
        stopInertiaPan()

        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            let location = touch.location(in: self)

            // 数字格：按下显示预览（不启动翻开 timer）
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

        let texture = glassmorphismBackgroundTexture(size: size)
        backgroundNode = SKSpriteNode(texture: texture, size: size)
        backgroundNode.position = CGPoint(x: frame.midX, y: frame.midY)
        backgroundNode.zPosition = -10
        addChild(backgroundNode)
    }

    private func glassmorphismBackgroundTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let baseImage = renderer.image { ctx in
            let cg = ctx.cgContext

            // 1) 底色渐变（冷灰蓝）
            let bg1 = UIColor(red: 0.86, green: 0.90, blue: 0.96, alpha: 1).cgColor
            let bg2 = UIColor(red: 0.74, green: 0.80, blue: 0.90, alpha: 1).cgColor
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [bg1, bg2] as CFArray,
                                  locations: [0, 1])!
            cg.drawLinearGradient(
                grad,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            // 2) 柔和光斑（你图2那种彩色大圆）
            func addBlob(center: CGPoint, radius: CGFloat, color: UIColor, alpha: CGFloat) {
                let colors = [
                    color.withAlphaComponent(alpha).cgColor,
                    color.withAlphaComponent(0).cgColor
                ] as CFArray

                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: colors,
                                   locations: [0, 1])!

                cg.saveGState()
                cg.drawRadialGradient(
                    g,
                    startCenter: center, startRadius: 0,
                    endCenter: center, endRadius: radius,
                    options: [.drawsAfterEndLocation]
                )
                cg.restoreGState()
            }

            // 左上偏暖
            addBlob(center: CGPoint(x: size.width * 0.20, y: size.height * 0.18),
                    radius: min(size.width, size.height) * 0.45,
                    color: UIColor(red: 1.00, green: 0.55, blue: 0.25, alpha: 1),
                    alpha: 0.55)

            // 右上偏蓝
            addBlob(center: CGPoint(x: size.width * 0.85, y: size.height * 0.22),
                    radius: min(size.width, size.height) * 0.50,
                    color: UIColor(red: 0.25, green: 0.65, blue: 1.00, alpha: 1),
                    alpha: 0.45)

            // 左下偏紫
            addBlob(center: CGPoint(x: size.width * 0.28, y: size.height * 0.88),
                    radius: min(size.width, size.height) * 0.55,
                    color: UIColor(red: 0.72, green: 0.35, blue: 1.00, alpha: 1),
                    alpha: 0.35)

            // 3) 很轻的“雾化”叠层，让层次更像玻璃拟态
            cg.setFillColor(UIColor.white.withAlphaComponent(0.06).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
        }

        // 4) 轻微高斯模糊（让光斑更柔）
        guard let blurred = gaussianBlur(image: baseImage, radius: 18) else {
            return SKTexture(image: baseImage)
        }
        return SKTexture(image: blurred)
    }

    private func gaussianBlur(image: UIImage, radius: CGFloat) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)

        guard let output = filter?.outputImage else { return nil }

        // GaussianBlur 会把边界变大，这里裁回原尺寸
        let cropRect = ciImage.extent
        let cropped = output.cropped(to: cropRect)

        let context = CIContext(options: nil)
        guard let cg = context.createCGImage(cropped, from: cropRect) else { return nil }
        return UIImage(cgImage: cg)
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
                               y: boardNode.position.y - translation.y) // UIKit Y 反向
        let clamped = clampedBoardOrigin(proposed: proposed)
        boardNode.position = clamped
    }
}
