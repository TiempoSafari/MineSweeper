import UIKit

protocol StartMenuViewDelegate: AnyObject {
    func startMenuView(_ menuView: StartMenuView, didSelectModeAt index: Int)
}

struct StartMenuMode {
    let title: String
    let iconName: String
    let contentView: UIView
}

final class StartMenuView: UIView {
    weak var delegate: StartMenuViewDelegate?

    private let modes: [StartMenuMode]
    private let tabBar = UITabBar()
    private let contentView = UIView()

    init(modes: [StartMenuMode]) {
        self.modes = modes
        super.init(frame: .zero)
        configureView()
        configureTabs()
        layoutContentViews()
        selectMode(at: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureView() {
        backgroundColor = .clear
        contentView.translatesAutoresizingMaskIntoConstraints = false
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.delegate = self

        addSubview(contentView)
        addSubview(tabBar)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: tabBar.topAnchor),

            tabBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            tabBar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func configureTabs() {
        let items = modes.enumerated().map { index, mode in
            UITabBarItem(title: mode.title, image: UIImage(systemName: mode.iconName), tag: index)
        }
        tabBar.items = items
        tabBar.selectedItem = items.first

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    private func layoutContentViews() {
        modes.forEach { mode in
            let view = mode.contentView
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                view.topAnchor.constraint(equalTo: contentView.topAnchor),
                view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
    }

    private func selectMode(at index: Int) {
        for (modeIndex, mode) in modes.enumerated() {
            mode.contentView.isHidden = modeIndex != index
        }
    }
}

extension StartMenuView: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        selectMode(at: item.tag)
        delegate?.startMenuView(self, didSelectModeAt: item.tag)
    }
}
