import UIKit

final class PlaceholderModeCoordinator: GameModeCoordinating {
    let kind: GameModeKind
    let title: String
    let iconName: String
    let startMenuView: UIView

    init(kind: GameModeKind, title: String, iconName: String, message: String) {
        self.kind = kind
        self.title = title
        self.iconName = iconName
        self.startMenuView = PlaceholderStartView(title: "\(title)模式", message: message)
    }
}
