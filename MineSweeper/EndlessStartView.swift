import UIKit

final class EndlessStartView: UIView {
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

        let cardView = makeEndlessCardView()

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "无尽模式"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "探索地雷迷宫，成长并深入"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center

        let startButton = UIButton(type: .system)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.setTitle("开始探索", for: .normal)
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

        let tipsLabel = UILabel()
        tipsLabel.translatesAutoresizingMaskIntoConstraints = false
        tipsLabel.text = "揭开安全格子前进，踩雷只会受伤但不会立即结束。"
        tipsLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        tipsLabel.textColor = .tertiaryLabel
        tipsLabel.textAlignment = .center
        tipsLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [cardView, titleLabel, subtitleLabel, glassButton, tipsLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
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

    private func makeEndlessCardView() -> UIView {
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
            UIColor(red: 0.42, green: 0.36, blue: 0.92, alpha: 1).cgColor,
            UIColor(red: 0.16, green: 0.12, blue: 0.42, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.frame = CGRect(origin: .zero, size: CGSize(width: cardSize, height: cardSize))
        background.layer.insertSublayer(gradient, at: 0)

        let badge = UILabel()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.text = "∞"
        badge.font = UIFont.systemFont(ofSize: 54, weight: .bold)
        badge.textColor = UIColor.white.withAlphaComponent(0.85)

        let caption = UILabel()
        caption.translatesAutoresizingMaskIntoConstraints = false
        caption.text = "探索"
        caption.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        caption.textColor = UIColor.white.withAlphaComponent(0.8)

        background.addSubview(badge)
        background.addSubview(caption)
        card.addSubview(background)

        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: cardSize),
            card.heightAnchor.constraint(equalToConstant: cardSize),

            background.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            background.topAnchor.constraint(equalTo: card.topAnchor),
            background.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            badge.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            badge.centerYAnchor.constraint(equalTo: background.centerYAnchor, constant: -6),

            caption.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            caption.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 6)
        ])

        let floatAnimation = CABasicAnimation(keyPath: "transform.translation.y")
        floatAnimation.fromValue = -4
        floatAnimation.toValue = 4
        floatAnimation.duration = 2.8
        floatAnimation.autoreverses = true
        floatAnimation.repeatCount = .infinity
        floatAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        card.layer.add(floatAnimation, forKey: "float")

        return card
    }
}
