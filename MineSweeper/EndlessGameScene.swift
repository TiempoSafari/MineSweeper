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
    private struct Room {
        let rowRange: ClosedRange<Int>
        let colRange: ClosedRange<Int>

        var tiles: Set<String> {
            var results = Set<String>()
            for row in rowRange {
                for col in colRange {
                    results.insert("\(row)-\(col)")
                }
            }
            return results
        }

        var center: (Int, Int) {
            let row = (rowRange.lowerBound + rowRange.upperBound) / 2
            let col = (colRange.lowerBound + colRange.upperBound) / 2
            return (row, col)
        }
    }

    weak var endlessDelegate: EndlessGameSceneDelegate?

    private let worldGenerator = WorldGenerator()
    private let eventSystem = EventSystem()
    private let skillSystem = SkillSystem()

    private var gridLogic: GridLogic?
    private var currentArea: Area?

    private var boardNode = SKNode()
    private var tileNodes: [[SKSpriteNode]] = []
    private var tileLabels: [[SKLabelNode]] = []
    private var tileSize: CGFloat = 30
    private var boardOrigin = CGPoint.zero

    private var playerController = PlayerController(position: .zero)
    private var playerNode = SKSpriteNode()

    private var joystickBase = SKShapeNode(circleOfRadius: 42)
    private var joystickKnob = SKShapeNode(circleOfRadius: 18)
    private var joystickTouch: UITouch?
    private var joystickVector = CGVector.zero

    private var lastUpdateTime: TimeInterval = 0
    private var mineTriggered: Set<String> = []

    private var itemNodes: [String: SKSpriteNode] = [:]
    private var enemyNodes: [String: SKSpriteNode] = [:]

    private var rooms: [Room] = []
    private var roomTiles: Set<String> = []
    private var portalTile: (Int, Int)?
    private var portalNode: SKSpriteNode?

    private var pendingAreaCompletion = false
    private var currentTileCoord: (Int, Int)?

    private lazy var textures = PixelTextures()

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
        pendingAreaCompletion = false
        currentTileCoord = nil
        portalNode = nil

        let area = worldGenerator.generateArea(index: index)
        currentArea = area

        rooms = generateRooms(rows: area.rows, cols: area.cols)
        roomTiles = rooms.reduce(into: Set<String>()) { result, room in
            result.formUnion(room.tiles)
        }

        let safeTiles = roomTiles
        gridLogic = GridLogic(rows: area.rows, cols: area.cols, mineCount: area.mines, safePositions: safeTiles)

        tileSize = min(38, max(22, 300 / CGFloat(max(area.rows, area.cols))))
        let gridWidth = CGFloat(area.cols) * tileSize
        let gridHeight = CGFloat(area.rows) * tileSize
        boardOrigin = CGPoint(x: -gridWidth / 2 + tileSize / 2, y: -gridHeight / 2 + tileSize / 2)

        buildTiles(rows: area.rows, cols: area.cols)
        setupPlayer()
        setupPortal()
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

        guard joystickVector != .zero else { return }
        let velocity = CGVector(dx: joystickVector.dx * playerController.moveSpeed,
                                dy: joystickVector.dy * playerController.moveSpeed)
        let newPosition = CGPoint(x: playerNode.position.x + velocity.dx * delta,
                                  y: playerNode.position.y + velocity.dy * delta)

        guard let (row, col) = tileCoordinate(for: newPosition) else { return }
        guard let tile = gridLogic.tile(atRow: row, col: col) else { return }

        if tile.state == .unrevealed {
            revealTileForMovement(row: row, col: col)
        }

        if tile.state == .revealed {
            playerNode.position = newPosition
            playerController.position = newPosition
            if currentTileCoord?.0 != row || currentTileCoord?.1 != col {
                currentTileCoord = (row, col)
                handleTileEntry(row: row, col: col)
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
                let tile = SKSpriteNode(texture: textures.unrevealed)
                tile.size = CGSize(width: tileSize, height: tileSize)
                tile.texture?.filteringMode = .nearest
                tile.position = pointForTile(row: row, col: col)
                tile.zPosition = 1

                let label = SKLabelNode(fontNamed: "Menlo-Bold")
                label.fontSize = tileSize * 0.45
                label.fontColor = .white
                label.alpha = 0
                label.position = CGPoint(x: 0, y: -tileSize * 0.22)
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
        playerNode = SKSpriteNode(texture: textures.player)
        playerNode.size = CGSize(width: tileSize * 0.75, height: tileSize * 0.75)
        playerNode.texture?.filteringMode = .nearest
        playerNode.zPosition = 10
        addChild(playerNode)
    }

    private func setupPortal() {
        guard let portalRoom = rooms.randomElement() else { return }
        let (row, col) = portalRoom.center
        portalTile = (row, col)

        let portal = SKSpriteNode(texture: textures.portal)
        portal.size = CGSize(width: tileSize * 0.7, height: tileSize * 0.7)
        portal.texture?.filteringMode = .nearest
        portal.position = pointForTile(row: row, col: col)
        portal.zPosition = 6
        portal.alpha = 0
        boardNode.addChild(portal)
        portalNode = portal
    }

    private func revealInitialTile() {
        guard let gridLogic, let area = currentArea else { return }
        let startRoom = rooms.first ?? Room(rowRange: 0...0, colRange: 0...0)
        let (startRow, startCol) = startRoom.center
        let revealed = gridLogic.reveal(row: startRow, col: startCol)
        applyRevealChanges(revealed)
        let position = pointForTile(row: startRow, col: startCol)
        playerNode.position = position
        playerController.position = position
        currentTileCoord = (startRow, startCol)
        handleTileEntry(row: startRow, col: startCol)
    }

    private func revealTileForMovement(row: Int, col: Int) {
        guard let gridLogic else { return }
        let revealed = gridLogic.reveal(row: row, col: col)
        applyRevealChanges(revealed)
        updateHUD()
    }

    private func applyRevealChanges(_ revealed: [GridTile]) {
        for tile in revealed {
            let node = tileNodes[tile.row][tile.col]
            let label = tileLabels[tile.row][tile.col]
            let tileKey = self.tileKey(row: tile.row, col: tile.col)
            let isRoomTile = roomTiles.contains(tileKey)

            node.texture = textureForRevealedTile(isRoom: isRoomTile, isMine: tile.hasMine)
            node.texture?.filteringMode = .nearest

            if tile.hasMine {
                label.text = "!"
                label.alpha = 1
            } else if tile.adjacentMines > 0 {
                label.text = "\(tile.adjacentMines)"
                label.alpha = 1
            }

            if let portal = portalTile, portal.0 == tile.row, portal.1 == tile.col {
                portalNode?.alpha = 1
            }
        }
    }

    private func textureForRevealedTile(isRoom: Bool, isMine: Bool) -> SKTexture {
        if isMine {
            return textures.mine
        }
        return isRoom ? textures.roomFloor : textures.revealed
    }

    private func handleTileEntry(row: Int, col: Int) {
        guard let gridLogic else { return }
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

        if let portal = portalTile, portal.0 == row, portal.1 == col {
            handlePortalEntry()
        }

        collectItemIfNeeded(at: key)
        updateHUD()
    }

    private func handlePortalEntry() {
        guard !pendingAreaCompletion else { return }
        pendingAreaCompletion = true
        let skills = skillSystem.randomSkills(count: 3)
        endlessDelegate?.endlessScene(self, presentSkillChoices: skills)
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
        let enemy = SKSpriteNode(texture: textures.enemy)
        enemy.size = CGSize(width: tileSize * 0.6, height: tileSize * 0.6)
        enemy.texture?.filteringMode = .nearest
        enemy.position = pointForTile(row: row, col: col)
        enemy.zPosition = 5
        boardNode.addChild(enemy)
        enemyNodes[key] = enemy
    }

    private func spawnItem(_ item: Item, atRow row: Int, col: Int) {
        let key = tileKey(row: row, col: col)
        guard itemNodes[key] == nil else { return }
        let drop = SKSpriteNode(texture: textures.item)
        drop.size = CGSize(width: tileSize * 0.5, height: tileSize * 0.5)
        drop.texture?.filteringMode = .nearest
        drop.position = pointForTile(row: row, col: col)
        drop.zPosition = 4

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

    private func generateRooms(rows: Int, cols: Int) -> [Room] {
        var generated: [Room] = []
        let roomCount = min(5, max(3, rows / 6))
        var attempts = 0

        while generated.count < roomCount && attempts < 40 {
            attempts += 1
            let roomRows = Int.random(in: 4...min(7, rows - 2))
            let roomCols = Int.random(in: 4...min(7, cols - 2))
            let startRow = Int.random(in: 1...(rows - roomRows - 1))
            let startCol = Int.random(in: 1...(cols - roomCols - 1))
            let rowRange = startRow...(startRow + roomRows - 1)
            let colRange = startCol...(startCol + roomCols - 1)

            let newRoom = Room(rowRange: rowRange, colRange: colRange)
            let overlaps = generated.contains { existing in
                rowRange.overlaps(existing.rowRange) && colRange.overlaps(existing.colRange)
            }
            if !overlaps {
                generated.append(newRoom)
            }
        }

        if generated.isEmpty {
            generated.append(Room(rowRange: 0...min(3, rows - 1), colRange: 0...min(3, cols - 1)))
        }

        return generated
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

private final class PixelTextures {
    let unrevealed = PixelTextures.makePixelTexture(fill: UIColor(red: 0.18, green: 0.2, blue: 0.26, alpha: 1), border: UIColor(red: 0.3, green: 0.32, blue: 0.4, alpha: 1))
    let revealed = PixelTextures.makePixelTexture(fill: UIColor(red: 0.36, green: 0.38, blue: 0.46, alpha: 1), border: UIColor(red: 0.48, green: 0.5, blue: 0.6, alpha: 1))
    let roomFloor = PixelTextures.makePixelTexture(fill: UIColor(red: 0.22, green: 0.3, blue: 0.24, alpha: 1), border: UIColor(red: 0.32, green: 0.42, blue: 0.34, alpha: 1))
    let mine = PixelTextures.makePixelTexture(fill: UIColor(red: 0.46, green: 0.18, blue: 0.2, alpha: 1), border: UIColor(red: 0.7, green: 0.35, blue: 0.3, alpha: 1))
    let player = PixelTextures.makePixelTexture(fill: UIColor(red: 0.28, green: 0.86, blue: 0.5, alpha: 1), border: UIColor.white)
    let portal = PixelTextures.makePortalTexture()
    let item = PixelTextures.makePixelTexture(fill: UIColor(red: 0.96, green: 0.84, blue: 0.2, alpha: 1), border: UIColor.white)
    let enemy = PixelTextures.makePixelTexture(fill: UIColor(red: 0.92, green: 0.3, blue: 0.3, alpha: 1), border: UIColor.white)

    private static func makePixelTexture(fill: UIColor, border: UIColor) -> SKTexture {
        let size = CGSize(width: 16, height: 16)
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        defer { UIGraphicsEndImageContext() }
        fill.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        border.setStroke()
        let borderPath = UIBezierPath(rect: CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5))
        borderPath.lineWidth = 1
        borderPath.stroke()
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else { return SKTexture() }
        return SKTexture(image: image)
    }

    private static func makePortalTexture() -> SKTexture {
        let size = CGSize(width: 16, height: 16)
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        defer { UIGraphicsEndImageContext() }

        UIColor(red: 0.2, green: 0.18, blue: 0.35, alpha: 1).setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

        let glow = UIColor(red: 0.74, green: 0.55, blue: 0.96, alpha: 1)
        glow.setFill()
        UIBezierPath(roundedRect: CGRect(x: 3, y: 3, width: 10, height: 10), cornerRadius: 2).fill()

        UIColor.white.setFill()
        UIBezierPath(rect: CGRect(x: 6, y: 6, width: 4, height: 4)).fill()

        guard let image = UIGraphicsGetImageFromCurrentImageContext() else { return SKTexture() }
        return SKTexture(image: image)
    }
}
