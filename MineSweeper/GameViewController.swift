import UIKit
import SpriteKit
import GameplayKit

/// 游戏主界面控制器，负责加载 SpriteKit 场景并管理 UIKit HUD/TabBar。
// MARK: - GameViewController

final class GameViewController: UIViewController {

    // MARK: Properties
    /// 当前呈现的游戏场景（由 SKView 持有，这里弱引用避免循环）。
    private weak var gameScene: GameScene?
    /// 手势：用于拖拽棋盘（带惯性）。
    private var panGesture: UIPanGestureRecognizer?

    // 开始界面
    private var startMenuView: StartMenuView?

    // 游戏内帮助按钮（系统 Toolbar）
    private var helpToolbar: UIToolbar?
    private var currentHintSuggestion: GameScene.HintSuggestion?

    // 难度选择弹窗（用于允许取消）
    private weak var difficultyAlert: UIAlertController?

    // 系统级 HUD（iOS 26 自动 Liquid Glass）
    private var hudView: UIVisualEffectView?
    private var hudTitleLabel: UILabel?
    private var hudSubtitleLabel: UILabel?

    // 计时 HUD（与主 HUD 同风格，显示在右侧）
    private var timerView: UIVisualEffectView?
    private var timerLabel: UILabel?
    private var hudStackView: UIStackView?
    private var gameTimer: Timer?
    private var gameStartTime: Date?
    private var elapsedSeconds: Int = 0

    /// 当前选择的难度配置。
    private var currentDifficulty: DifficultyOption?

    /// 预设难度列表（用于弹窗）。
    private let difficulties: [DifficultyOption] = [
        DifficultyOption(title: "入门", rows: 9,  cols: 9,  mines: 10, icon: "sparkles"),
        DifficultyOption(title: "简单", rows: 12, cols: 9,  mines: 18, icon: "leaf"),
        DifficultyOption(title: "中等", rows: 16, cols: 9,  mines: 30, icon: "circle.grid.3x3"),
        DifficultyOption(title: "困难", rows: 16, cols: 16, mines: 40, icon: "mountain.2"),
        DifficultyOption(title: "专家", rows: 30, cols: 16, mines: 80, icon: "flame"),
        DifficultyOption(title: "大师", rows: 30, cols: 30, mines: 160, icon: "crown")
    ]

    // MARK: Lifecycle

    /// 加载场景并初始化 UIKit 组件。
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
            
//            skView.showsFPS = true
//            skView.showsNodeCount = true
            skView.showsFPS = false
            skView.showsNodeCount = false
            skView.showsDrawCount = false
            skView.showsPhysics = false
            skView.showsFields = false


            gameScene = sceneNode
            sceneNode.uiDelegate = self

            configurePanGesture()
            configureStartMenu()
            configureSystemHUD()
            configureHelpToolbar()

            setStartMenuVisible(true, animated: false)
            setHUDVisible(false, animated: false)
            setHelpToolbarVisible(false, animated: false)

        }
    }

    /// 支持的屏幕方向（手机禁用倒置）。
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone { return .allButUpsideDown }
        return .all
    }

    /// 隐藏状态栏以获得沉浸式体验。
    override var prefersStatusBarHidden: Bool { true }
}

// MARK: - Difficulty Alert (system)

extension GameViewController {

    /// 弹出难度选择弹窗，并在选择后开始游戏。
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
                self.difficultyAlert = nil
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

        let cancelAction = UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.difficultyAlert = nil
        }
        alert.addAction(cancelAction)

        difficultyAlert = alert
        present(alert, animated: true)
    }

    @objc private func handleStartGameTapped() {
        presentDifficultyAlert()
    }
}

// MARK: - Start Menu TabBar

extension GameViewController {

    /// 创建并布局开始界面（包含 TabBar + 内容区）。
    private func configureStartMenu() {
        let traditionalView = TraditionalStartView { [weak self] in
            self?.handleStartGameTapped()
        }
        let challengeView = PlaceholderStartView(title: "闯关模式", message: "敬请期待")
        let endlessView = PlaceholderStartView(title: "无尽模式", message: "敬请期待")

        let modes: [StartMenuMode] = [
            StartMenuMode(title: "传统", iconName: "square.grid.2x2", contentView: traditionalView),
            StartMenuMode(title: "闯关", iconName: "flag.checkered", contentView: challengeView),
            StartMenuMode(title: "无尽", iconName: "infinity", contentView: endlessView)
        ]

        let menuView = StartMenuView(modes: modes)
        menuView.translatesAutoresizingMaskIntoConstraints = false
        menuView.delegate = self
        view.addSubview(menuView)

        NSLayoutConstraint.activate([
            menuView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            menuView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            menuView.topAnchor.constraint(equalTo: view.topAnchor),
            menuView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        startMenuView = menuView
    }

    /// 显示/隐藏开始界面，支持动画过渡。
    private func setStartMenuVisible(_ visible: Bool, animated: Bool) {
        guard let menuView = startMenuView else { return }
        menuView.isUserInteractionEnabled = visible

        if !animated {
            menuView.isHidden = !visible
            menuView.alpha = visible ? 1 : 0
            return
        }

        if visible { menuView.isHidden = false }
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            menuView.alpha = visible ? 1 : 0
        } completion: { _ in
            menuView.isHidden = !visible
        }
    }
}

// MARK: - System HUD (Liquid Glass via system material)

extension GameViewController {

    /// 创建并布局顶部 HUD（标题 + 副标题）。
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

        let timer = makeTimerHUD(effect: effect)

        let stack = UIStackView(arrangedSubviews: [hud, timer])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 10

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            hud.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.72)
        ])

        hud.alpha = 0
        hud.isHidden = true

        hudView = hud
        hudTitleLabel = title
        hudSubtitleLabel = subtitle
        timerView = timer
        hudStackView = stack
    }

    /// 更新 HUD 文本内容。
    private func updateHUD(title: String, subtitle: String) {
        hudTitleLabel?.text = title
        hudSubtitleLabel?.text = subtitle
    }

    /// 创建计时 HUD（与主 HUD 同材质风格）。
    private func makeTimerHUD(effect: UIBlurEffect) -> UIVisualEffectView {
        let hud = UIVisualEffectView(effect: effect)
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.isUserInteractionEnabled = false

        hud.layer.cornerRadius = 18
        hud.layer.masksToBounds = true
        hud.layer.borderWidth = 0.8
        hud.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.text = "00:00"

        hud.contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: hud.contentView.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: hud.contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: hud.contentView.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: hud.contentView.bottomAnchor, constant: -10)
        ])

        hud.alpha = 0
        hud.isHidden = true
        timerLabel = label
        return hud
    }

    /// 显示/隐藏 HUD，支持动画过渡。
    private func setHUDVisible(_ visible: Bool, animated: Bool) {
        guard let hud = hudView, let timer = timerView, let stack = hudStackView else { return }

        if !animated {
            hud.isHidden = !visible
            timer.isHidden = !visible
            stack.isHidden = !visible
            hud.alpha = visible ? 1 : 0
            timer.alpha = visible ? 1 : 0
            return
        }

        if visible {
            hud.isHidden = false
            timer.isHidden = false
            stack.isHidden = false
        }
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            hud.alpha = visible ? 1 : 0
            timer.alpha = visible ? 1 : 0
        } completion: { _ in
            hud.isHidden = !visible
            timer.isHidden = !visible
            stack.isHidden = !visible
        }
    }

    /// 重置计时显示（未开始计时）。
    private func resetTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
        gameStartTime = nil
        elapsedSeconds = 0
        updateTimerLabel(seconds: 0)
    }

    /// 启动计时（首次翻开格子时触发）。
    private func startTimer() {
        guard gameTimer == nil else { return }
        gameStartTime = Date()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickTimer()
        }
    }

    /// 停止计时并返回已用秒数。
    private func stopTimer() -> Int {
        gameTimer?.invalidate()
        gameTimer = nil
        return elapsedSeconds
    }

    /// 每秒刷新一次计时显示。
    private func tickTimer() {
        guard let start = gameStartTime else { return }
        elapsedSeconds = max(0, Int(Date().timeIntervalSince(start)))
        updateTimerLabel(seconds: elapsedSeconds)
    }

    /// 将秒数格式化为 mm:ss。
    private func updateTimerLabel(seconds: Int) {
        let minutes = seconds / 60
        let secs = seconds % 60
        timerLabel?.text = String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Help Toolbar

extension GameViewController {

    private func configureHelpToolbar() {
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.isTranslucent = true

        let helpItem = UIBarButtonItem(
            title: "帮助",
            style: .plain,
            target: self,
            action: #selector(handleHelpTappedFromToolbar)
        )

        toolbar.items = [helpItem]
        toolbar.setContentHuggingPriority(.required, for: .horizontal)
        toolbar.setContentCompressionResistancePriority(.required, for: .horizontal)

        view.addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            toolbar.heightAnchor.constraint(equalToConstant: 44),
            toolbar.widthAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])

        toolbar.alpha = 0
        toolbar.isHidden = true
        helpToolbar = toolbar
    }

    private func setHelpToolbarVisible(_ visible: Bool, animated: Bool) {
        guard let toolbar = helpToolbar else { return }

        if !animated {
            toolbar.isHidden = !visible
            toolbar.alpha = visible ? 1 : 0
            return
        }

        if visible { toolbar.isHidden = false }
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            toolbar.alpha = visible ? 1 : 0
        } completion: { _ in
            toolbar.isHidden = !visible
        }
    }

    @objc private func handleHelpTapped() {
        guard let suggestion = gameScene?.requestHintSuggestion() else {
            let alert = UIAlertController(title: "提示", message: "暂时没有可用的提示。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
            return
        }

        currentHintSuggestion = suggestion
        let message = """
        根据已翻开的数字格推理，当前可确定 \(suggestion.reasonedMineCount) 个必为地雷的格子。
        点击“应用”会自动为这些格子插旗。
        """

        let alert = UIAlertController(title: "推理分析", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.gameScene?.cancelHintSuggestion()
            self?.currentHintSuggestion = nil
        })
        alert.addAction(UIAlertAction(title: "应用", style: .default) { [weak self] _ in
            guard let self, let suggestion = self.currentHintSuggestion else { return }
            self.gameScene?.applyHintSuggestion(suggestion)
            self.currentHintSuggestion = nil
        })
        present(alert, animated: true)
    }

    @objc private func handleHelpTappedFromToolbar() {
        handleHelpTapped()
    }
}

// MARK: - Pan Gesture

extension GameViewController {

    /// 添加拖拽手势，用于移动棋盘。
    private func configurePanGesture() {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        gesture.maximumNumberOfTouches = 1
        view.addGestureRecognizer(gesture)
        panGesture = gesture
    }

    /// 处理拖拽手势：拖动中移动棋盘，结束时启用惯性滚动。
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        if presentedViewController != nil { return }
        if startMenuView?.isHidden == false { return }

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

    /// 游戏场景请求显示开始菜单（选择难度）。
    func gameSceneDidRequestStartMenu(_ scene: GameScene) {
        setStartMenuVisible(true, animated: true)
        setHUDVisible(false, animated: true)
        setHelpToolbarVisible(false, animated: true)
        resetTimer()
        currentHintSuggestion = nil
    }

    /// 游戏正式开始：显示 HUD/TabBar。
    func gameSceneDidStartGame(_ scene: GameScene) {
        setStartMenuVisible(false, animated: true)
        setHUDVisible(true, animated: true)
        setHelpToolbarVisible(true, animated: true)
        resetTimer()
        currentHintSuggestion = nil
    }

    /// 首次翻开格子时启动计时。
    func gameSceneDidStartTimer(_ scene: GameScene) {
        startTimer()
    }

    /// 旗子数量变化时更新 HUD 文本。
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

    /// 游戏结束（胜/负），弹窗提示并回到开始界面。
    func gameScene(_ scene: GameScene, didEndWithWin didWin: Bool) {
        let title = didWin ? "扫雷成功" : "扫雷失败"
        let elapsed = stopTimer()
        let timeText = String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
        let message = didWin
            ? "恭喜你清除了所有地雷。\n用时 \(timeText)。"
            : "你踩到了地雷。"

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            scene.showStartState()
            self.setStartMenuVisible(true, animated: true)
            self.setHUDVisible(false, animated: true)
            self.setHelpToolbarVisible(false, animated: true)
        }))

        present(alert, animated: true)
    }
}

// MARK: - StartMenuViewDelegate

extension GameViewController: StartMenuViewDelegate {
    func startMenuView(_ menuView: StartMenuView, didSelectModeAt index: Int) {
        if index != 0 {
            dismissDifficultyAlertIfNeeded()
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
    /// 通过 KVC 为 UIAlertAction 注入系统图标（非公开 API）。
    func setSystemIcon(_ image: UIImage?) {
        self.setValue(image, forKey: "image")
    }
}

private extension GameViewController {
    func dismissDifficultyAlertIfNeeded() {
        guard let alert = difficultyAlert else { return }
        alert.dismiss(animated: true)
        difficultyAlert = nil
    }
}
