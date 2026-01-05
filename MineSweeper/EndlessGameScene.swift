import SpriteKit
import UIKit

protocol EndlessGameSceneDelegate: AnyObject {
    func endlessSceneDidRequestStartMenu(_ scene: EndlessGameScene)
    func endlessScene(_ scene: EndlessGameScene, didUpdateHUD title: String, subtitle: String)
    func endlessScene(_ scene: EndlessGameScene, presentSkillChoices skills: [Skill])
    func endlessSceneDidRequestAreaChoice(_ scene: EndlessGameScene, areaIndex: Int)
    func endlessScene(_ scene: EndlessGameScene, didShowEvent message: String)
}

final class EndlessGameScene: SKScene {
    weak var endlessDelegate: EndlessGameSceneDelegate?

    private let worldGenerator = WorldGenerator()
    private let eventSystem = EventSystem()
    private let skillSystem = SkillSystem()

    private var gridLogic: GridLogic?
    private var currentArea: Area?

    private var boardNode = SKNode()
    private var tileNodes: [[SKShapeNode]] = []
    private var tileLabels: [[SKLabelNode]] = []
    private var tileSize: CGFloat = 36
    private var boardOrigin = CGPoint.zero

    private var playerController = PlayerController(position: .zero)
    private var playerNode = SKShapeNode(circleOfRadius: 14)

    private var joystickBase = SKShapeNode(circleOfRadius: 42)
    private var joystickKnob = SKShapeNode(circleOfRadius: 18)
    private var joystickTouch: UITouch?
    private var joystickVector = CGVector.zero

    private var lastUpdateTime: TimeInterval = 0
    private var revealedSafeTiles: Int = 0
    private var mineTriggered: Set<String> = []

    private var itemNodes: [String: SKShapeNode] = [:]
    private var enemyNodes: [String: SKShapeNode] = [:]

    private var pendingAreaCompletion = false

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        if boardNode.parent == nil {
            addChild(boardNode)
        }

        configureJoystick()
        startArea(index: 0)
    }

    func startArea(index: Int) {
        boardNode.removeAllChildren()
        tileNodes.removeAll()
        tileLabels.removeAll()
        itemNodes.removeAll()
        enemyNodes.removeAll()
        mineTriggered.removeAll()
        revealedSafeTiles = 0
        pendingAreaCompletion = false

        let area = worldGenerator.generateArea(index: index)
        currentArea = area
        gridLogic = GridLogic(rows: area.rows, cols: area.cols, mineCount: area.mines)

        tileSize = min(48, max(26, 320 / CGFloat(max(area.rows, area.cols))))
        let gridWidth = CGFloat(area.cols) * tileSize
        let gridHeight = CGFloat(area.rows) * tileSize
        boardOrigin = CGPoint(x: -gridWidth / 2 + tileSize / 2, y: -gridHeight / 2 + tileSize / 2)

        buildTiles(rows: area.rows, cols: area.cols)
        setupPlayer()
        revealInitialTile()
        updateHUD()
    }

    func selectSkill(_ skill: Skill) {
        playerController.apply(skill: skill)
        updateHUD()
        if pendingAreaCompletion, let areaIndex = currentArea?.index {
            pendingAreaCompletion = false
            endlessDelegate?.endlessSceneDidRequestAreaChoice(self, areaIndex: areaIndex)
        }
    }

    func continueToNextArea() {
        let nextIndex = (currentArea?.index ?? 0) + 1
        startArea(index: nextIndex)
    }

    func exitToMenu() {
        endlessDelegate?.endlessSceneDidRequestStartMenu(self)
    }

    override func update(_ currentTime: TimeInterval) {
        guard let gridLogic else { return }
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }
        let delta = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        if joystickVector != .zero {
            let velocity = CGVector(dx: joystickVector.dx * playerController.moveSpeed,
                                    dy: joystickVector.dy * playerController.moveSpeed)
            let newPosition = CGPoint(x: playerNode.position.x + velocity.dx * delta,
                                      y: playerNode.position.y + velocity.dy * delta)
            if canMove(to: newPosition, gridLogic: gridLogic) {
                playerNode.position = newPosition
                playerController.position = newPosition
                handleTileEntry(at: newPosition)
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard joystickTouch == nil else { return }
        if let touch = touches.first {
            let location = touch.location(in: self)
            if joystickBase.contains(location) {
                joystickTouch = touch
                updateJoystick(location: location)
                return
            }
        }
        if let touch = touches.first {
            let location = touch.location(in: self)
            if let (row, col) = tileCoordinate(for: location) {
                revealTile(row: row, col: col)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch = joystickTouch else { return }
        if touches.contains(activeTouch) {
            let location = activeTouch.location(in: self)
            updateJoystick(location: location)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch = joystickTouch else { return }
        if touches.contains(activeTouch) {
            resetJoystick()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch = joystickTouch else { return }
        if touches.contains(activeTouch) {
            resetJoystick()
        }
    }

    private func configureJoystick() {
        joystickBase.removeAllChildren()
        joystickBase.removeFromParent()
        joystickKnob.removeFromParent()

        joystickBase = SKShapeNode(circleOfRadius: 42)
        joystickBase.fillColor = SKColor.white.withAlphaComponent(0.08)
        joystickBase.strokeColor = SKColor.white.withAlphaComponent(0.25)
        joystickBase.lineWidth = 1
        joystickBase.position = CGPoint(x: -size.width * 0.35, y: -size.height * 0.28)
        joystickBase.zPosition = 40

        joystickKnob = SKShapeNode(circleOfRadius: 18)
        joystickKnob.fillColor = SKColor.white.withAlphaComponent(0.5)
        joystickKnob.strokeColor = SKColor.white.withAlphaComponent(0.2)
        joystickKnob.lineWidth = 1
        joystickKnob.position = .zero
        joystickKnob.zPosition = 41

        joystickBase.addChild(joystickKnob)
        addChild(joystickBase)
    }

    private func updateJoystick(location: CGPoint) {
        let vector = CGVector(dx: location.x - joystickBase.position.x,
                              dy: location.y - joystickBase.position.y)
        let length = hypot(vector.dx, vector.dy)
        let maxLength: CGFloat = 32
        let clampedLength = min(length, maxLength)
        let angle = atan2(vector.dy, vector.dx)
        joystickKnob.position = CGPoint(x: cos(angle) * clampedLength, y: sin(angle) * clampedLength)
        if length > 0 {
            joystickVector = CGVector(dx: cos(angle), dy: sin(angle))
        }
    }

    private func resetJoystick() {
        joystickTouch = nil
        joystickVector = .zero
        let reset = SKAction.move(to: .zero, duration: 0.12)
        reset.timingMode = .easeOut
        joystickKnob.run(reset)
    }

    private func buildTiles(rows: Int, cols: Int) {
        tileNodes = Array(repeating: [], count: rows)
        tileLabels = Array(repeating: [], count: rows)

        for row in 0..<rows {
            for col in 0..<cols {
                let tile = SKShapeNode(rectOf: CGSize(width: tileSize - 2, height: tileSize - 2), cornerRadius: 6)
                tile.fillColor = SKColor(red: 0.2, green: 0.24, blue: 0.3, alpha: 1)
                tile.strokeColor = SKColor.white.withAlphaComponent(0.08)
                tile.lineWidth = 1
                tile.position = pointForTile(row: row, col: col)
                tile.zPosition = 1

                let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
                label.fontSize = 14
                label.fontColor = .white
                label.alpha = 0
                label.position = CGPoint(x: 0, y: -6)
                label.zPosition = 2

                tile.addChild(label)
                boardNode.addChild(tile)

                tileNodes[row].append(tile)
                tileLabels[row].append(label)
            }
        }
    }

    private func setupPlayer() {
        playerNode.removeFromParent()
        playerNode = SKShapeNode(circleOfRadius: tileSize * 0.32)
        playerNode.fillColor = SKColor.systemGreen
        playerNode.strokeColor = SKColor.white.withAlphaComponent(0.4)
        playerNode.lineWidth = 1
        playerNode.zPosition = 10
        addChild(playerNode)
    }

    private func revealInitialTile() {
        guard let gridLogic, let area = currentArea else { return }
        let startRow = area.rows / 2
        let startCol = area.cols / 2
        let revealed = gridLogic.reveal(row: startRow, col: startCol)
        applyRevealChanges(revealed)
        let position = pointForTile(row: startRow, col: startCol)
        playerNode.position = position
        playerController.position = position
        handleTileEntry(at: position)
    }

    private func revealTile(row: Int, col: Int) {
        guard let gridLogic else { return }
        let revealed = gridLogic.reveal(row: row, col: col)
        applyRevealChanges(revealed)
        updateHUD()
        if revealed.contains(where: { $0.hasMine }) {
            endlessDelegate?.endlessScene(self, didShowEvent: "踩到地雷会造成伤害，谨慎探索！")
        }
    }

    private func applyRevealChanges(_ revealed: [GridTile]) {
        for tile in revealed {
            let node = tileNodes[tile.row][tile.col]
            let label = tileLabels[tile.row][tile.col]
            node.fillColor = SKColor(red: 0.38, green: 0.4, blue: 0.45, alpha: 1)

            if tile.hasMine {
                label.text = "💥"
                label.alpha = 1
                node.fillColor = SKColor(red: 0.46, green: 0.2, blue: 0.22, alpha: 1)
            } else if tile.adjacentMines > 0 {
                label.text = "\(tile.adjacentMines)"
                label.alpha = 1
            }

            if !tile.hasMine {
                revealedSafeTiles += 1
            }
        }

        checkAreaCompletion()
    }

    private func checkAreaCompletion() {
        guard let gridLogic else { return }
        if gridLogic.remainingSafeTiles() == 0 {
            pendingAreaCompletion = true
            let skills = skillSystem.randomSkills(count: 3)
            endlessDelegate?.endlessScene(self, presentSkillChoices: skills)
        }
    }

    private func canMove(to position: CGPoint, gridLogic: GridLogic) -> Bool {
        guard let (row, col) = tileCoordinate(for: position) else { return false }
        guard let tile = gridLogic.tile(atRow: row, col: col) else { return false }
        return tile.state == .revealed
    }

    private func handleTileEntry(at position: CGPoint) {
        guard let gridLogic, let (row, col) = tileCoordinate(for: position) else { return }
        guard let tile = gridLogic.tile(atRow: row, col: col) else { return }
        let key = tileKey(row: row, col: col)

        if tile.hasMine, !mineTriggered.contains(key) {
            mineTriggered.insert(key)
            let baseDamage = (Double.random(in: 0...1) < (currentArea?.specialMineChance ?? 0)) ? 4 : 2
            let scaledDamage = max(1, Int(CGFloat(baseDamage) * playerController.mineDamageMultiplier))
            let isDead = playerController.takeDamage(scaledDamage)
            let damageText = baseDamage > 2 ? "强化地雷爆炸，损失 \(scaledDamage) 点生命" : "地雷爆炸，损失 \(scaledDamage) 点生命"
            endlessDelegate?.endlessScene(self, didShowEvent: damageText)
            if isDead {
                endlessDelegate?.endlessScene(self, didShowEvent: "生命耗尽，返回营地。")
                exitToMenu()
                return
            }
        }

        if !tile.hasBeenVisited {
            gridLogic.setVisited(row: row, col: col)
            triggerExplorationEvent(at: row, col: col)
        }

        if playerController.revealRadiusBonus > 0 {
            let revealed = gridLogic.revealNeighbors(fromRow: row, col: col, radius: playerController.revealRadiusBonus)
            applyRevealChanges(revealed)
        }

        collectItemIfNeeded(at: key)
        updateHUD()
    }

    private func triggerExplorationEvent(at row: Int, col: Int) {
        if let event = eventSystem.rollEvent() {
            endlessDelegate?.endlessScene(self, didShowEvent: "\(event.title)：\(event.description)")
            handleEvent(event, at: row, col: col)
        }

        let dropChance = 0.18 + Double(playerController.itemDropRateBonus)
        if Double.random(in: 0...1) < dropChance {
            let item = generateItem()
            spawnItem(item, atRow: row, col: col)
        }
    }

    private func handleEvent(_ event: RandomEvent, at row: Int, col: Int) {
        switch event.type {
        case .enemySpawn:
            spawnEnemy(atRow: row, col: col)
        case .challenge:
            let skills = skillSystem.randomSkills(count: 3)
            endlessDelegate?.endlessScene(self, presentSkillChoices: skills)
        case .reward:
            let item = generateItem()
            spawnItem(item, atRow: row, col: col)
        case .trap:
            playerController.mineDamageMultiplier *= 1.2
        }
    }

    private func spawnEnemy(atRow row: Int, col: Int) {
        let key = tileKey(row: row, col: col)
        guard enemyNodes[key] == nil else { return }
        let enemy = SKShapeNode(circleOfRadius: tileSize * 0.26)
        enemy.fillColor = SKColor.systemRed
        enemy.strokeColor = SKColor.white.withAlphaComponent(0.3)
        enemy.position = pointForTile(row: row, col: col)
        enemy.zPosition = 5
        boardNode.addChild(enemy)
        enemyNodes[key] = enemy
    }

    private func spawnItem(_ item: Item, atRow row: Int, col: Int) {
        let key = tileKey(row: row, col: col)
        guard itemNodes[key] == nil else { return }
        let drop = SKShapeNode(circleOfRadius: tileSize * 0.22)
        drop.fillColor = SKColor.systemYellow
        drop.strokeColor = SKColor.white.withAlphaComponent(0.2)
        drop.position = pointForTile(row: row, col: col)
        drop.zPosition = 4

        let label = SKLabelNode(fontNamed: "HelveticaNeue")
        label.fontSize = 10
        label.text = "物"
        label.fontColor = .black
        label.position = CGPoint(x: 0, y: -4)
        drop.addChild(label)

        boardNode.addChild(drop)
        itemNodes[key] = drop
        drop.name = item.name
    }

    private func collectItemIfNeeded(at key: String) {
        guard let node = itemNodes[key] else { return }
        let itemName = node.name ?? "未知装备"
        node.removeFromParent()
        itemNodes.removeValue(forKey: key)

        let item = generateItem(nameOverride: itemName)
        let equipped = playerController.equip(item: item)
        if let equipped {
            endlessDelegate?.endlessScene(self, didShowEvent: "获得\(equipped.name)（\(equipped.rarity.displayName)）")
        }
    }

    private func generateItem(nameOverride: String? = nil) -> Item {
        let rarity = ItemRarity.allCases.randomElement() ?? .common
        let slots: [ItemSlot] = [.tool, .armor, .module]
        let slot = slots.randomElement() ?? .tool
        let powerBase: Int = rarity == .common ? 1 : (rarity == .rare ? 2 : 4)
        let power = powerBase + Int.random(in: 0...2)
        let name = nameOverride ?? "\(slotName(slot))\(rarity.displayName)"
        let description = "提供探索增益"
        return Item(name: name, slot: slot, rarity: rarity, power: power, description: description)
    }

    private func slotName(_ slot: ItemSlot) -> String {
        switch slot {
        case .tool: return "探测器"
        case .armor: return "护甲"
        case .module: return "模块"
        case .none: return "物品"
        }
    }

    private func pointForTile(row: Int, col: Int) -> CGPoint {
        CGPoint(x: boardOrigin.x + CGFloat(col) * tileSize,
                y: boardOrigin.y + CGFloat(row) * tileSize)
    }

    private func tileCoordinate(for scenePoint: CGPoint) -> (Int, Int)? {
        let local = boardNode.convert(scenePoint, from: self)
        let col = Int(round((local.x - boardOrigin.x) / tileSize))
        let row = Int(round((local.y - boardOrigin.y) / tileSize))
        guard let gridLogic else { return nil }
        if row >= 0, row < gridLogic.rows, col >= 0, col < gridLogic.cols {
            return (row, col)
        }
        return nil
    }

    private func tileKey(row: Int, col: Int) -> String {
        "\(row)-\(col)"
    }

    private func updateHUD() {
        guard let area = currentArea else { return }
        let equipmentText = [ItemSlot.tool, .armor, .module].compactMap { slot -> String? in
            guard let item = playerController.equipment[slot] else { return nil }
            return item.name
        }
        let subtitle = "区域 \(area.index + 1) · 生命 \(playerController.hp)/\(playerController.maxHP) · 装备 \(equipmentText.isEmpty ? "无" : equipmentText.joined(separator: "/"))"
        endlessDelegate?.endlessScene(self, didUpdateHUD: "无尽探索", subtitle: subtitle)
    }
}
