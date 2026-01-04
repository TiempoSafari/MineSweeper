import UIKit

final class TraditionalModeCoordinator: GameModeCoordinating {
    let kind: GameModeKind = .traditional
    let title: String = "传统"
    let iconName: String = "square.grid.2x2"
    let startMenuView: UIView

    struct DifficultyOption {
        let title: String
        let rows: Int
        let cols: Int
        let mines: Int
        let icon: String
    }

    init() {
        startMenuView = TraditionalStartView { [weak self] in
            self?.handleStartRequested()
        }
    }

    weak var presentingViewController: UIViewController?
    weak var gameScene: GameScene?

    var onHUDUpdate: ((String, String) -> Void)?

    private weak var difficultyAlert: UIAlertController?
    private(set) var currentDifficulty: DifficultyOption?

    private let difficulties: [DifficultyOption] = [
        DifficultyOption(title: "入门", rows: 9, cols: 9, mines: 10, icon: "sparkles"),
        DifficultyOption(title: "简单", rows: 12, cols: 9, mines: 18, icon: "leaf"),
        DifficultyOption(title: "中等", rows: 16, cols: 9, mines: 30, icon: "circle.grid.3x3"),
        DifficultyOption(title: "困难", rows: 16, cols: 16, mines: 40, icon: "mountain.2"),
        DifficultyOption(title: "专家", rows: 30, cols: 16, mines: 80, icon: "flame"),
        DifficultyOption(title: "大师", rows: 30, cols: 30, mines: 160, icon: "crown")
    ]

    func handleStartRequested() {
        presentDifficultyAlert()
    }

    func dismissDifficultyAlertIfNeeded() {
        guard let alert = difficultyAlert else { return }
        alert.dismiss(animated: true)
        difficultyAlert = nil
    }

    func didDeselect() {
        dismissDifficultyAlertIfNeeded()
    }

    func resetSelection() {
        currentDifficulty = nil
    }

    func updateHUDForFlags(flagged: Int, mineCount: Int) {
        if let opt = currentDifficulty {
            onHUDUpdate?("扫雷", "\(opt.title) · \(opt.rows)×\(opt.cols) · 雷 \(mineCount) · 标记 \(flagged)")
        } else {
            onHUDUpdate?("扫雷", "雷 \(mineCount) · 标记 \(flagged)")
        }
    }

    private func presentDifficultyAlert() {
        guard let presenter = presentingViewController else { return }
        if presenter.presentedViewController != nil { return }

        let alert = UIAlertController(
            title: "扫雷",
            message: nil,
            preferredStyle: .alert
        )

        for opt in difficulties {
            let action = UIAlertAction(title: opt.title, style: .default) { [weak self] _ in
                guard let self else { return }
                self.difficultyAlert = nil
                self.currentDifficulty = opt
                self.onHUDUpdate?("扫雷", "\(opt.title) · \(opt.rows)×\(opt.cols) · 雷 \(opt.mines) · 标记 0")
                self.gameScene?.startGame(rows: opt.rows, cols: opt.cols, mines: opt.mines)
            }

            action.setSystemIcon(UIImage(systemName: opt.icon))
            alert.addAction(action)
        }

        let cancelAction = UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.difficultyAlert = nil
        }
        alert.addAction(cancelAction)

        difficultyAlert = alert
        presenter.present(alert, animated: true)
    }
}
