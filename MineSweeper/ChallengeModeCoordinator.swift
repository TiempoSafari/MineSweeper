import UIKit

final class ChallengeModeCoordinator: GameModeCoordinating {
    struct LevelDefinition {
        let title: String
        let rows: Int
        let cols: Int
        let mines: Int
        let goals: [String]
        let reward: String
        let difficultyHint: String
        let coefficient: Int
        let rewardItem: ItemType
    }

    enum ItemType: CaseIterable, Hashable {
        case unlocker
        case scanner
        case autoFlag
        case timeRewind

        var title: String {
            switch self {
            case .unlocker: return "解锁器"
            case .scanner: return "雷区探测"
            case .autoFlag: return "自动旗子"
            case .timeRewind: return "时间倒流"
            }
        }

        var iconName: String {
            switch self {
            case .unlocker: return "lock.open"
            case .scanner: return "scope"
            case .autoFlag: return "flag"
            case .timeRewind: return "clock.arrow.circlepath"
            }
        }
    }

    let kind: GameModeKind = .challenge
    let title: String = "闯关"
    let iconName: String = "flag.checkered"
    lazy var startMenuView: UIView = {
        ChallengeStartView(
            levels: levels,
            unlockedIndex: unlockedLevelIndex,
            completedIndices: completedLevels
        ) { [weak self] index in
            self?.startLevel(at: index)
        }
    }()

    weak var gameScene: GameScene?
    var onHUDUpdate: ((String, String) -> Void)?
    var onItemsUpdate: (([ItemType: Int]) -> Void)?

    private(set) var currentLevelIndex: Int?
    private var unlockedLevelIndex: Int = 0
    private let totalLevels: Int = 18
    private let levelsPerCoefficient: Int = 3
    private var completedLevels: Set<Int> = []
    private var itemInventory: [ItemType: Int] = [.unlocker: 1]

    private lazy var levels: [LevelDefinition] = {
        (0..<totalLevels).map { index in
            makeLevelDefinition(for: index)
        }
    }()

    func didSelect() {
        refreshStartView()
        onItemsUpdate?(itemInventory)
    }

    func resetSelection() {
        currentLevelIndex = nil
        refreshStartView()
    }

    func updateHUDForFlags(flagged: Int, mineCount: Int) {
        if let index = currentLevelIndex {
            let level = levels[index]
            onHUDUpdate?(
                "闯关 · 第\(index + 1)关",
                "\(level.difficultyHint) · 系数 \(level.coefficient) · \(level.rows)×\(level.cols) · 雷 \(mineCount) · 标记 \(flagged)"
            )
        } else {
            onHUDUpdate?("闯关", "雷 \(mineCount) · 标记 \(flagged)")
        }
    }

    func handleGameEnd(didWin: Bool) {
        guard didWin, let index = currentLevelIndex else { return }
        completedLevels.insert(index)
        if index == unlockedLevelIndex {
            unlockedLevelIndex = min(unlockedLevelIndex + 1, levels.count - 1)
        }
        grantReward(for: index)
        refreshStartView()
    }

    func consumeItem(_ item: ItemType) -> Bool {
        let count = itemInventory[item, default: 0]
        guard count > 0 else { return false }
        itemInventory[item] = count - 1
        onItemsUpdate?(itemInventory)
        return true
    }

    func refundItem(_ item: ItemType) {
        itemInventory[item, default: 0] += 1
        onItemsUpdate?(itemInventory)
    }

    private func startLevel(at index: Int) {
        guard levels.indices.contains(index) else { return }
        guard index == unlockedLevelIndex else { return }
        guard !completedLevels.contains(index) else { return }
        let level = levels[index]
        currentLevelIndex = index
        onHUDUpdate?(
            "闯关 · 第\(index + 1)关",
            "\(level.difficultyHint) · 系数 \(level.coefficient) · \(level.rows)×\(level.cols) · 雷 \(level.mines) · 标记 0"
        )
        gameScene?.startChallengeGame(rows: level.rows, cols: level.cols, mines: level.mines, coefficient: level.coefficient)
    }

    private func refreshStartView() {
        guard let view = startMenuView as? ChallengeStartView else { return }
        view.updateLevels(
            levels: levels,
            unlockedIndex: unlockedLevelIndex,
            completedIndices: completedLevels,
            selectedIndex: currentLevelIndex
        )
    }

    private func makeLevelDefinition(for index: Int) -> LevelDefinition {
        let coefficient = index / levelsPerCoefficient + 1
        let tierOffset = index % levelsPerCoefficient
        let title = "挑战 \(index + 1)"
        let baseRows = 8 + coefficient
        let baseCols = 8 + coefficient
        let rows = min(16, baseRows + tierOffset)
        let cols = min(14, baseCols + (tierOffset / 2))
        let density = min(0.16 + Double(coefficient) * 0.02, 0.28)
        let mines = max(8, min(Int(Double(rows * cols) * density), rows * cols - 1))

        let goals = [
            "在 \(12 + coefficient * 2) 回合内完成",
            "无误标记",
            "在 \(90 + coefficient * 15) 秒内完成"
        ]
        let rewardItem = rewardItemForLevel(index)
        let reward = "\(rewardItem.title) +1"
        let difficultyHint = "阶段 \(coefficient)"

        return LevelDefinition(
            title: title,
            rows: rows,
            cols: cols,
            mines: mines,
            goals: goals,
            reward: reward,
            difficultyHint: difficultyHint,
            coefficient: coefficient,
            rewardItem: rewardItem
        )
    }

    private func rewardItemForLevel(_ index: Int) -> ItemType {
        let rotation: [ItemType] = [.unlocker, .scanner, .autoFlag, .timeRewind]
        return rotation[index % rotation.count]
    }

    private func grantReward(for levelIndex: Int) {
        let rewardItem = levels[levelIndex].rewardItem
        itemInventory[rewardItem, default: 0] += 1
        onItemsUpdate?(itemInventory)
    }
}
