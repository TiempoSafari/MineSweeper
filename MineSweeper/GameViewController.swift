//
//  GameViewController.swift
//  MineSweeper
//
//  System alert difficulty + system UITabBar + system Liquid-Glass HUD overlay
//

import UIKit
import SpriteKit
import GameplayKit

final class GameViewController: UIViewController {

    private weak var gameScene: GameScene?
    private var panGesture: UIPanGestureRecognizer?

    // 系统级底部导航（iOS 26 自动 Liquid Glass）
    private var systemTabBar: UITabBar?

    // 系统级 HUD（iOS 26 自动 Liquid Glass）
    private var hudView: UIVisualEffectView?
    private var hudTitleLabel: UILabel?
    private var hudSubtitleLabel: UILabel?

    private var currentDifficulty: DifficultyOption?

    private let difficulties: [DifficultyOption] = [
        DifficultyOption(title: "入门", rows: 9,  cols: 9,  mines: 10, icon: "sparkles"),
        DifficultyOption(title: "简单", rows: 12, cols: 9,  mines: 18, icon: "leaf"),
        DifficultyOption(title: "中等", rows: 16, cols: 9,  mines: 30, icon: "circle.grid.3x3"),
        DifficultyOption(title: "困难", rows: 16, cols: 16, mines: 40, icon: "mountain.2"),
        DifficultyOption(title: "专家", rows: 30, cols: 16, mines: 80, icon: "flame"),
        DifficultyOption(title: "大师", rows: 30, cols: 30, mines: 160, icon: "crown")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        if let scene = GKScene(fileNamed: "GameScene"),
           let sceneNode = scene.rootNode as? GameScene,
           let skView = self.view as? SKView {

            sceneNode.entities = scene.entities
            sceneNode.graphs = scene.graphs
            sceneNode.scaleMode = .aspectFill

            skView.presentScene(sceneNode)
            skView.ignoresSiblingOrder = true
            skView.showsFPS = true
            skView.showsNodeCount = true

            gameScene = sceneNode
            sceneNode.uiDelegate = self

            configurePanGesture()
            configureSystemTabBar()
            configureSystemHUD()

            setSystemTabBarVisible(false, animated: false)
            setHUDVisible(false, animated: false)

            DispatchQueue.main.async { [weak self] in
                self?.presentDifficultyAlert()
            }
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone { return .allButUpsideDown }
        return .all
    }

    override var prefersStatusBarHidden: Bool { true }
}

// MARK: - Difficulty Alert (system)

extension GameViewController {

    private func presentDifficultyAlert() {
        if presentedViewController != nil { return }

        let alert = UIAlertController(
            title: "扫雷",
            message: nil,          // ✅ 去掉“选择难度开始”& 小胶囊
            preferredStyle: .alert
        )

        for opt in difficulties {
            let action = UIAlertAction(title: opt.title, style: .default) { [weak self] _ in
                guard let self else { return }
                self.currentDifficulty = opt

                // 先写入 HUD 基础信息（标记数会通过 delegate 实时更新）
                self.updateHUD(
                    title: "扫雷",
                    subtitle: "\(opt.title) · \(opt.rows)×\(opt.cols) · 雷 \(opt.mines) · 标记 0"
                )

                self.gameScene?.startGame(rows: opt.rows, cols: opt.cols, mines: opt.mines)
            }

            // ✅ UIAlertAction 没有公开 image 属性，用 KVC 注入
            action.setSystemIcon(UIImage(systemName: opt.icon))

            alert.addAction(action)
        }

        present(alert, animated: true)
    }
}

// MARK: - System UITabBar (in-game only)

extension GameViewController {

    private func configureSystemTabBar() {
        let tabBar = UITabBar()
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.delegate = self

        let item1 = UITabBarItem(title: "功能1", image: UIImage(systemName: "circle.grid.2x2"), tag: 0)
        let item2 = UITabBarItem(title: "功能2", image: UIImage(systemName: "wand.and.stars"), tag: 1)
        let item3 = UITabBarItem(title: "功能3", image: UIImage(systemName: "gearshape"), tag: 2)
        tabBar.items = [item1, item2, item3]
        tabBar.selectedItem = item2

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance

        view.addSubview(tabBar)
        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        systemTabBar = tabBar
    }

    private func setSystemTabBarVisible(_ visible: Bool, animated: Bool) {
        guard let tabBar = systemTabBar else { return }
        tabBar.isUserInteractionEnabled = visible

        if !animated {
            tabBar.isHidden = !visible
            tabBar.alpha = visible ? 1 : 0
            return
        }

        if visible { tabBar.isHidden = false }
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            tabBar.alpha = visible ? 1 : 0
        } completion: { _ in
            tabBar.isHidden = !visible
        }
    }
}

// MARK: - System HUD (Liquid Glass via system material)

extension GameViewController {

    private func configureSystemHUD() {
        let effect = UIBlurEffect(style: .systemUltraThinMaterial)
        let hud = UIVisualEffectView(effect: effect)
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.isUserInteractionEnabled = false

        hud.layer.cornerRadius = 18
        hud.layer.masksToBounds = true
        hud.layer.borderWidth = 0.8
        hud.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        title.textColor = .label
        title.textAlignment = .center
        title.text = "扫雷"

        let subtitle = UILabel()
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = .secondaryLabel
        subtitle.textAlignment = .center
        subtitle.text = ""

        hud.contentView.addSubview(title)
        hud.contentView.addSubview(subtitle)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: hud.contentView.topAnchor, constant: 10),
            title.leadingAnchor.constraint(equalTo: hud.contentView.leadingAnchor, constant: 14),
            title.trailingAnchor.constraint(equalTo: hud.contentView.trailingAnchor, constant: -14),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            subtitle.leadingAnchor.constraint(equalTo: hud.contentView.leadingAnchor, constant: 14),
            subtitle.trailingAnchor.constraint(equalTo: hud.contentView.trailingAnchor, constant: -14),
            subtitle.bottomAnchor.constraint(equalTo: hud.contentView.bottomAnchor, constant: -10)
        ])

        view.addSubview(hud)
        NSLayoutConstraint.activate([
            hud.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hud.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            hud.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.86)
        ])

        hud.alpha = 0
        hud.isHidden = true

        hudView = hud
        hudTitleLabel = title
        hudSubtitleLabel = subtitle
    }

    private func updateHUD(title: String, subtitle: String) {
        hudTitleLabel?.text = title
        hudSubtitleLabel?.text = subtitle
    }

    private func setHUDVisible(_ visible: Bool, animated: Bool) {
        guard let hud = hudView else { return }

        if !animated {
            hud.isHidden = !visible
            hud.alpha = visible ? 1 : 0
            return
        }

        if visible { hud.isHidden = false }
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            hud.alpha = visible ? 1 : 0
        } completion: { _ in
            hud.isHidden = !visible
        }
    }
}

// MARK: - Pan Gesture

extension GameViewController {

    private func configurePanGesture() {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        gesture.maximumNumberOfTouches = 1
        view.addGestureRecognizer(gesture)
        panGesture = gesture
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        if presentedViewController != nil { return }
        if systemTabBar?.isHidden != false { return }

        guard let view = self.view else { return }

        switch gesture.state {
        case .began:
            gameScene?.stopInertiaPan()

        case .changed:
            let translation = gesture.translation(in: view)
            gameScene?.panBoard(by: translation)
            gesture.setTranslation(.zero, in: view)

        case .ended, .cancelled, .failed:
            let velocity = gesture.velocity(in: view)
            gameScene?.startInertiaPan(initialVelocity: velocity)

        default:
            break
        }
    }
}

// MARK: - GameSceneDelegate

extension GameViewController: GameSceneDelegate {

    func gameSceneDidRequestStartMenu(_ scene: GameScene) {
        setSystemTabBarVisible(false, animated: true)
        setHUDVisible(false, animated: true)
        presentDifficultyAlert()
    }

    func gameSceneDidStartGame(_ scene: GameScene) {
        setSystemTabBarVisible(true, animated: true)
        setHUDVisible(true, animated: true)
    }

    func gameScene(_ scene: GameScene, didUpdateFlagCount flagged: Int, mineCount: Int) {
        if let opt = currentDifficulty {
            updateHUD(
                title: "扫雷",
                subtitle: "\(opt.title) · \(opt.rows)×\(opt.cols) · 雷 \(mineCount) · 标记 \(flagged)"
            )
        } else {
            updateHUD(title: "扫雷", subtitle: "雷 \(mineCount) · 标记 \(flagged)")
        }
    }

    func gameScene(_ scene: GameScene, didEndWithWin didWin: Bool) {
        let title = didWin ? "扫雷成功" : "扫雷失败"
        let message = didWin ? "恭喜你清除了所有地雷。" : "你踩到了地雷。"

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            scene.showStartState()
            self.setSystemTabBarVisible(false, animated: true)
            self.setHUDVisible(false, animated: true)
            self.presentDifficultyAlert()
        }))

        present(alert, animated: true)
    }
}

// MARK: - UITabBarDelegate (placeholders)

extension GameViewController: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        switch item.tag {
        case 0:
            // TODO: 功能1 占位
            break
        case 1:
            // TODO: 功能2 占位
            break
        case 2:
            // TODO: 功能3 占位
            break
        default:
            break
        }
    }
}

// MARK: - Models

private struct DifficultyOption {
    let title: String
    let rows: Int
    let cols: Int
    let mines: Int
    let icon: String
}

// MARK: - UIAlertAction icon helper (KVC)

private extension UIAlertAction {
    func setSystemIcon(_ image: UIImage?) {
        self.setValue(image, forKey: "image")
    }
}
