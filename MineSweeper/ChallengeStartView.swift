import UIKit

final class ChallengeStartView: UIView {
    private let levels: [ChallengeModeCoordinator.LevelDefinition]
    private let onStart: (Int) -> Void

    private let progressLabel = UILabel()
    private let levelTitleLabel = UILabel()
    private let levelDetailLabel = UILabel()
    private let difficultyBadge = UILabel()
    private let goalsStack = UIStackView()
    private let segmentedControl: UISegmentedControl
    private let startButton = UIButton(type: .system)

    private var selectedIndex: Int = 0
    private var unlockedIndex: Int = 0
    private var baseLevelTitle: String = ""
    private var completedIndices: Set<Int> = []

    init(
        levels: [ChallengeModeCoordinator.LevelDefinition],
        unlockedIndex: Int,
        completedIndices: Set<Int>,
        onStart: @escaping (Int) -> Void
    ) {
        self.levels = levels
        self.unlockedIndex = unlockedIndex
        self.completedIndices = completedIndices
        self.onStart = onStart
        self.segmentedControl = UISegmentedControl(items: levels.enumerated().map { "\($0.offset + 1)" })
        super.init(frame: .zero)
        configureView()
        updateLevelDisplay(index: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureView() {
        backgroundColor = .clear

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "闯关模式"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "逐关挑战，完成目标推进下一关"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center

        let levelCard = makeLevelCard()
        let buttonView = makeStartButton()

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(handleSegmentChanged), for: .valueChanged)
        updateSegmentStates()

        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        progressLabel.textColor = .secondaryLabel
        progressLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, progressLabel, segmentedControl, levelCard, buttonView])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            segmentedControl.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func makeLevelCard() -> UIView {
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 18
        card.layer.masksToBounds = true
        card.layer.borderWidth = 0.8
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor

        levelTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        levelTitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        levelTitleLabel.textColor = .label

        levelDetailLabel.translatesAutoresizingMaskIntoConstraints = false
        levelDetailLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        levelDetailLabel.textColor = .secondaryLabel
        levelDetailLabel.numberOfLines = 0

        difficultyBadge.translatesAutoresizingMaskIntoConstraints = false
        difficultyBadge.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        difficultyBadge.textColor = .systemBlue
        difficultyBadge.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        difficultyBadge.layer.cornerRadius = 10
        difficultyBadge.layer.masksToBounds = true
        difficultyBadge.textAlignment = .center

        goalsStack.translatesAutoresizingMaskIntoConstraints = false
        goalsStack.axis = .vertical
        goalsStack.spacing = 6
        goalsStack.alignment = .leading

        let headerStack = UIStackView(arrangedSubviews: [levelTitleLabel, difficultyBadge])
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .center

        let goalsTitle = UILabel()
        goalsTitle.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        goalsTitle.textColor = .label
        goalsTitle.text = "关卡目标"

        let contentStack = UIStackView(arrangedSubviews: [headerStack, levelDetailLabel, goalsTitle, goalsStack])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.alignment = .leading

        card.contentView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
            contentStack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 14),
            contentStack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -14),
            difficultyBadge.heightAnchor.constraint(equalToConstant: 20),
            difficultyBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])

        return card
    }

    private func makeStartButton() -> UIView {
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.setTitle("开始闯关", for: .normal)
        startButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        startButton.tintColor = .label
        startButton.addTarget(self, action: #selector(handleStartTapped), for: .touchUpInside)

        let glassButton = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        glassButton.translatesAutoresizingMaskIntoConstraints = false
        glassButton.layer.cornerRadius = 18
        glassButton.layer.masksToBounds = true
        glassButton.layer.borderWidth = 0.8
        glassButton.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor
        glassButton.contentView.addSubview(startButton)

        NSLayoutConstraint.activate([
            startButton.topAnchor.constraint(equalTo: glassButton.contentView.topAnchor, constant: 10),
            startButton.bottomAnchor.constraint(equalTo: glassButton.contentView.bottomAnchor, constant: -10),
            startButton.leadingAnchor.constraint(equalTo: glassButton.contentView.leadingAnchor, constant: 18),
            startButton.trailingAnchor.constraint(equalTo: glassButton.contentView.trailingAnchor, constant: -18)
        ])

        return glassButton
    }

    private func updateLevelDisplay(index: Int) {
        guard levels.indices.contains(index) else { return }
        selectedIndex = index
        let level = levels[index]

        baseLevelTitle = "第\(index + 1)关 · \(level.title)"
        levelTitleLabel.text = baseLevelTitle
        levelDetailLabel.text = "地图 \(level.rows)×\(level.cols) · 雷 \(level.mines)"
        difficultyBadge.text = "  \(level.difficultyHint)  "

        progressLabel.text = "当前关卡 第\(index + 1)关"

        goalsStack.arrangedSubviews.forEach { subview in
            goalsStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        level.goals.forEach { goal in
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
            label.textColor = .secondaryLabel
            label.text = "• \(goal)"
            goalsStack.addArrangedSubview(label)
        }

        updateSegmentStates()
    }

    @objc private func handleSegmentChanged() {
        updateLevelDisplay(index: segmentedControl.selectedSegmentIndex)
    }

    @objc private func handleStartTapped() {
        guard selectedIndex == unlockedIndex else { return }
        onStart(selectedIndex)
    }

    func updateLevels(
        levels: [ChallengeModeCoordinator.LevelDefinition],
        unlockedIndex: Int,
        completedIndices: Set<Int>,
        selectedIndex: Int?
    ) {
        guard levels.count == self.levels.count else { return }
        self.unlockedIndex = unlockedIndex
        self.completedIndices = completedIndices
        let activeIndex = min(unlockedIndex, levels.count - 1)
        segmentedControl.selectedSegmentIndex = activeIndex
        updateLevelDisplay(index: activeIndex)
    }

    private func updateSegmentStates() {
        for index in 0..<segmentedControl.numberOfSegments {
            let isCompleted = completedIndices.contains(index)
            let isActive = index == unlockedIndex && !isCompleted
            segmentedControl.setEnabled(isActive, forSegmentAt: index)
            let titlePrefix = isCompleted ? "✓" : ""
            segmentedControl.setTitle("\(titlePrefix)\(index + 1)", forSegmentAt: index)
        }

        let isCompleted = completedIndices.contains(selectedIndex)
        let isActive = selectedIndex == unlockedIndex && !isCompleted
        let titleSuffix = isCompleted ? "（已通关）" : "（未解锁）"
        levelTitleLabel.text = isActive ? baseLevelTitle : "\(baseLevelTitle)\(titleSuffix)"
        startButton.isEnabled = isActive
        startButton.alpha = isActive ? 1.0 : 0.5
    }
}
