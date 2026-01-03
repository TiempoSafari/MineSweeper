//
//  GameViewController.swift
//  MineSweeper
//
//  Updated: Center system difficulty alert + show bottom toolbar only in-game
//

import UIKit
import SpriteKit
import GameplayKit

final class GameViewController: UIViewController {

    private weak var gameScene: GameScene?
    private var panGesture: UIPanGestureRecognizer?
    private var bottomToolbar: UIToolbar?

    private let difficulties: [DifficultyOption] = [
        DifficultyOption(title: "入门", rows: 9,  cols: 9,  mines: 10),
        DifficultyOption(title: "简单", rows: 12, cols: 9,  mines: 18),
        DifficultyOption(title: "中等", rows: 16, cols: 9,  mines: 30),
        DifficultyOption(title: "困难", rows: 16, cols: 16, mines: 40),
        DifficultyOption(title: "专家", rows: 30, cols: 16, mines: 80),
        DifficultyOption(title: "大师", rows: 30, cols: 30, mines: 160)
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
            configureBottomToolbar()
            setToolbarVisible(false) // ✅ 初始隐藏：只有进入游戏后才显示

            // ✅ 启动即弹出“居中系统弹窗”选择难度
            DispatchQueue.main.async { [weak self] in
                self?.presentDifficultyAlert()
            }
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool { true }
}

// MARK: - Difficulty (Center System Alert)

extension GameViewController {
    private func presentDifficultyAlert() {
        // 避免重复弹
        if presentedViewController != nil { return }

        let alert = UIAlertController(
            title: "扫雷",
            message: "选择难度开始游戏",
            preferredStyle: .alert
        )

        // 逐个难度作为系统 action（iOS 26 自动 Liquid Glass）
        for opt in difficulties {
            let action = UIAlertAction(title: opt.title, style: .default) { [weak self] _ in
                self?.gameScene?.startGame(rows: opt.rows, cols: opt.cols, mines: opt.mines)
            }
            alert.addAction(action)
        }

        // 可选：给个“取消”（如果你希望必须选难度才能开始，也可以去掉）
        // alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        present(alert, animated: true)
    }
}

// MARK: - Bottom Toolbar (Shown only in-game)

extension GameViewController {
    private func configureBottomToolbar() {
        let tb = UIToolbar()
        tb.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tb)

        NSLayoutConstraint.activate([
            tb.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tb.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tb.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        // ✅ 三个占位功能选项（先占位，你后面再定义功能）
        let item1 = UIBarButtonItem(
            title: "功能1",
            image: UIImage(systemName: "circle.grid.2x2"),
            primaryAction: UIAction { _ in
                // TODO: 占位
            }
        )

        let item2 = UIBarButtonItem(
            title: "功能2",
            image: UIImage(systemName: "wand.and.stars"),
            primaryAction: UIAction { _ in
                // TODO: 占位
            }
        )

        let item3 = UIBarButtonItem(
            title: "功能3",
            image: UIImage(systemName: "gearshape"),
            primaryAction: UIAction { _ in
                // TODO: 占位
            }
        )

        let spacer = UIBarButtonItem(systemItem: .flexibleSpace)
        tb.setItems([item1, spacer, item2, spacer, item3], animated: false)

        // 系统外观（iOS 26 会自动用新材质语言）
        let appearance = UIToolbarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        tb.standardAppearance = appearance
        tb.scrollEdgeAppearance = appearance

        bottomToolbar = tb
    }

    private func setToolbarVisible(_ visible: Bool) {
        bottomToolbar?.isHidden = !visible
        bottomToolbar?.isUserInteractionEnabled = visible
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
        // 弹窗在时不允许拖拽
        if presentedViewController != nil { return }
        // 菜单状态（没开始）也不允许拖拽（toolbar 隐藏代表未开始/结束态）
        if bottomToolbar?.isHidden != false { return }

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
        // 回到“开始界面”：隐藏底部栏 + 弹出居中难度选择
        setToolbarVisible(false)
        presentDifficultyAlert()
    }

    func gameSceneDidStartGame(_ scene: GameScene) {
        // ✅ 进入游戏后才显示底部“系统导航栏”
        setToolbarVisible(true)
    }

    func gameScene(_ scene: GameScene, didEndWithWin didWin: Bool) {
        let title = didWin ? "扫雷成功" : "扫雷失败"
        let message = didWin ? "恭喜你清除了所有地雷。" : "你踩到了地雷。"

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self] _ in
            scene.showStartState()
            self?.setToolbarVisible(false)
            self?.presentDifficultyAlert()
        }))

        present(alert, animated: true)
    }
}

// MARK: - Models

private struct DifficultyOption {
    let title: String
    let rows: Int
    let cols: Int
    let mines: Int
}
