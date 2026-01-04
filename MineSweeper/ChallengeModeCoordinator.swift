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
    }

    let kind: GameModeKind = .challenge
    let title: String = "闯关"
    let iconName: String = "flag.checkered"
    lazy var startMenuView: UIView = {
        ChallengeStartView(levels: levels, unlockedIndex: unlockedLevelIndex) { [weak self] index in
            self?.startLevel(at: index)
        }
    }()

    weak var gameScene: GameScene?
    var onHUDUpdate: ((String, String) -> Void)?

    private(set) var currentLevelIndex: Int?
    private var unlockedLevelIndex: Int = 0
    private let totalLevels: Int = 18
    private let levelsPerCoefficient: Int = 3

    private lazy var levels: [LevelDefinition] = {
        (0..<totalLevels).map { index in
            makeLevelDefinition(for: index)
        }
    }()

    func didSelect() {
        refreshStartView()
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
        if index == unlockedLevelIndex {
            unlockedLevelIndex = min(unlockedLevelIndex + 1, levels.count - 1)
        }
        refreshStartView()
    }

    private func startLevel(at index: Int) {
        guard levels.indices.contains(index) else { return }
        guard index <= unlockedLevelIndex else { return }
        let level = levels[index]
        currentLevelIndex = index
        onHUDUpdate?(
            "闯关 · 第\(index + 1)关",
            "\(level.difficultyHint) · 系数 \(level.coefficient) · \(level.rows)×\(level.cols) · 雷 \(level.mines) · 标记 0"
        )
        gameScene?.startGame(rows: level.rows, cols: level.cols, mines: level.mines)
    }

    private func refreshStartView() {
        guard let view = startMenuView as? ChallengeStartView else { return }
        view.updateLevels(levels: levels, unlockedIndex: unlockedLevelIndex, selectedIndex: currentLevelIndex)
    }

    private func makeLevelDefinition(for index: Int) -> LevelDefinition {
        let coefficient = index / levelsPerCoefficient + 1
        let tierOffset = index % levelsPerCoefficient
        let title = "挑战 \(index + 1)"
        let baseRows = 8 + coefficient * 2
        let baseCols = 8 + coefficient * 2
        let rows = min(22, baseRows + tierOffset)
        let cols = min(18, baseCols + (tierOffset / 2))
        let density = min(0.22 + Double(coefficient) * 0.03, 0.36)
        let mines = max(8, min(Int(Double(rows * cols) * density), rows * cols - 1))

        let goals = [
            "在 \(10 + coefficient * 2) 回合内完成",
            "无误标记",
            "在 \(70 + coefficient * 20) 秒内完成"
        ]
        let reward = "解锁系数 \(coefficient) 奖励"
        let difficultyHint = "阶段 \(coefficient)"

        return LevelDefinition(
            title: title,
            rows: rows,
            cols: cols,
            mines: mines,
            goals: goals,
            reward: reward,
            difficultyHint: difficultyHint,
            coefficient: coefficient
        )
    }
}
