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
    }

    let kind: GameModeKind = .challenge
    let title: String = "闯关"
    let iconName: String = "flag.checkered"
    lazy var startMenuView: UIView = {
        ChallengeStartView(levels: levels) { [weak self] index in
            self?.startLevel(at: index)
        }
    }()

    weak var gameScene: GameScene?
    var onHUDUpdate: ((String, String) -> Void)?

    private(set) var currentLevelIndex: Int?

    private let levels: [LevelDefinition] = [
        LevelDefinition(
            title: "初入雷区",
            rows: 9,
            cols: 9,
            mines: 10,
            goals: ["在 12 回合内完成", "无误标记"],
            reward: "解锁雷区探测器",
            difficultyHint: "入门"
        ),
        LevelDefinition(
            title: "稳扎稳打",
            rows: 12,
            cols: 9,
            mines: 16,
            goals: ["在 90 秒内完成", "无误标记"],
            reward: "解锁时间倒流",
            difficultyHint: "简单"
        ),
        LevelDefinition(
            title: "陷阱边缘",
            rows: 12,
            cols: 12,
            mines: 24,
            goals: ["在 14 回合内完成", "连续翻开 3 区域"],
            reward: "解锁安全区域扫描",
            difficultyHint: "中等"
        ),
        LevelDefinition(
            title: "风暴中心",
            rows: 16,
            cols: 12,
            mines: 32,
            goals: ["在 120 秒内完成", "无误标记"],
            reward: "解锁自动旗子",
            difficultyHint: "困难"
        ),
        LevelDefinition(
            title: "深渊边界",
            rows: 16,
            cols: 16,
            mines: 45,
            goals: ["在 20 回合内完成", "连续翻开 4 区域"],
            reward: "解锁暂停雷区刷新",
            difficultyHint: "专家"
        ),
        LevelDefinition(
            title: "雷域王座",
            rows: 20,
            cols: 16,
            mines: 60,
            goals: ["在 150 秒内完成", "无误标记", "连胜 2 关"],
            reward: "解锁全图标记",
            difficultyHint: "大师"
        )
    ]

    func resetSelection() {
        currentLevelIndex = nil
    }

    func updateHUDForFlags(flagged: Int, mineCount: Int) {
        if let index = currentLevelIndex {
            let level = levels[index]
            onHUDUpdate?(
                "闯关 · 第\(index + 1)关",
                "\(level.difficultyHint) · \(level.rows)×\(level.cols) · 雷 \(mineCount) · 标记 \(flagged)"
            )
        } else {
            onHUDUpdate?("闯关", "雷 \(mineCount) · 标记 \(flagged)")
        }
    }

    private func startLevel(at index: Int) {
        guard levels.indices.contains(index) else { return }
        let level = levels[index]
        currentLevelIndex = index
        onHUDUpdate?(
            "闯关 · 第\(index + 1)关",
            "\(level.difficultyHint) · \(level.rows)×\(level.cols) · 雷 \(level.mines) · 标记 0"
        )
        gameScene?.startGame(rows: level.rows, cols: level.cols, mines: level.mines)
    }
}
