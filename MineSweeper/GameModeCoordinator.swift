import UIKit

enum GameModeKind {
    case traditional
    case challenge
    case endless
}

protocol GameModeCoordinating: AnyObject {
    var kind: GameModeKind { get }
    var title: String { get }
    var iconName: String { get }
    var startMenuView: UIView { get }

    func didSelect()
    func didDeselect()
}

extension GameModeCoordinating {
    func didSelect() {}
    func didDeselect() {}
}
