import UIKit

final class PlaceholderStartView: UIView {
    init(title: String, message: String) {
        super.init(frame: .zero)
        configureView(title: title, message: message)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureView(title: String, message: String) {
        backgroundColor = .clear

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = message
        messageLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])
    }
}
