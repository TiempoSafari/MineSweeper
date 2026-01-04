import UIKit

final class TraditionalStartView: UIView {
    private let onStart: () -> Void

    init(onStart: @escaping () -> Void) {
        self.onStart = onStart
        super.init(frame: .zero)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureView() {
        backgroundColor = .clear

        let cardView = makeMinesweeperCardView()

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "传统模式"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "选择难度开始游戏"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center

        let startButton = UIButton(type: .system)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.setTitle("开始游戏", for: .normal)
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

        let stack = UIStackView(arrangedSubviews: [cardView, titleLabel, subtitleLabel, glassButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])
    }

    @objc private func handleStartTapped() {
        onStart()
    }

    private func makeMinesweeperCardView() -> UIView {
        let cardSize: CGFloat = 170
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 20
        card.layer.masksToBounds = false
        card.layer.shadowColor = UIColor.black.withAlphaComponent(0.25).cgColor
        card.layer.shadowOpacity = 1
        card.layer.shadowRadius = 16
        card.layer.shadowOffset = CGSize(width: 0, height: 10)

        let background = UIView()
        background.translatesAutoresizingMaskIntoConstraints = false
        background.layer.cornerRadius = 20
        background.layer.masksToBounds = true

        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 0.65, green: 0.80, blue: 0.98, alpha: 1).cgColor,
            UIColor(red: 0.32, green: 0.55, blue: 0.88, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.frame = CGRect(origin: .zero, size: CGSize(width: cardSize, height: cardSize))
        background.layer.insertSublayer(gradient, at: 0)

        let grid = UIStackView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.axis = .vertical
        grid.spacing = 6
        grid.alignment = .center

        for row in 0..<3 {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 6
            rowStack.alignment = .center
            for col in 0..<3 {
                let tile = UILabel()
                tile.translatesAutoresizingMaskIntoConstraints = false
                tile.textAlignment = .center
                tile.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
                tile.textColor = .systemGreen
                tile.backgroundColor = UIColor.white.withAlphaComponent(0.85)
                tile.layer.cornerRadius = 8
                tile.layer.masksToBounds = true

                if row == 1 && col == 1 {
                    tile.text = "2"
                } else if row == 2 && col == 1 {
                    tile.text = "🚩"
                } else {
                    tile.text = ""
                }

                NSLayoutConstraint.activate([
                    tile.widthAnchor.constraint(equalToConstant: 38),
                    tile.heightAnchor.constraint(equalToConstant: 38)
                ])
                rowStack.addArrangedSubview(tile)
            }
            grid.addArrangedSubview(rowStack)
        }

        background.addSubview(grid)
        card.addSubview(background)

        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: cardSize),
            card.heightAnchor.constraint(equalToConstant: cardSize),

            background.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            background.topAnchor.constraint(equalTo: card.topAnchor),
            background.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            grid.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: background.centerYAnchor)
        ])

        card.transform = CGAffineTransform(rotationAngle: -0.06)

        let floatAnimation = CABasicAnimation(keyPath: "transform.translation.y")
        floatAnimation.fromValue = -4
        floatAnimation.toValue = 4
        floatAnimation.duration = 2.6
        floatAnimation.autoreverses = true
        floatAnimation.repeatCount = .infinity
        floatAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        card.layer.add(floatAnimation, forKey: "float")

        return card
    }
}
